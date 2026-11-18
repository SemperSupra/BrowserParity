package main

import (
 "bytes"
 "encoding/binary"
 "encoding/json"
 "errors"
 "fmt"
 "io"
 "os"
 "os/exec"
 "runtime"
 "strings"
 "testing"
 "time"
)

func wire(m message) []byte {
 b,_:=json.Marshal(m)
 var prefix [4]byte
 binary.LittleEndian.PutUint32(prefix[:],uint32(len(b)))
 return append(prefix[:],b...)
}
func decodeReplies(t *testing.T,raw []byte)[]reply{
 t.Helper()
 result:=[]reply{}
 reader:=bytes.NewReader(raw)
 for reader.Len()>0 {
  var length [4]byte
  if _,err:=io.ReadFull(reader,length[:]);err!=nil{t.Fatal(err)}
  n:=binary.LittleEndian.Uint32(length[:])
  if n<2||n>maxFrameBytes{t.Fatal("invalid reply framing")}
  b:=make([]byte,n)
  if _,err:=io.ReadFull(reader,b);err!=nil{t.Fatal(err)}
  var obj reply
  if err:=json.Unmarshal(b,&obj);err!=nil{t.Fatal(err)}
  result=append(result,obj)
 }
 return result
}
func TestHostHelperProcess(t *testing.T){
 if os.Getenv("R079_HELPER")=="1" {
  os.Exit(run(os.Stdin,os.Stdout))
 }
}
type childResult struct {exit int;output []byte;elapsed time.Duration;err error}
func invoke(input []byte,closeAfter bool)childResult{
 start:=time.Now()
 cmd:=exec.Command(os.Args[0],"-test.run=^TestHostHelperProcess$")
 cmd.Env=append(os.Environ(),"R079_HELPER=1")
 var stdout bytes.Buffer
 cmd.Stdout=&stdout
 var stderr bytes.Buffer
 cmd.Stderr=&stderr
 stdin,err:=cmd.StdinPipe()
 if err!=nil{return childResult{err:err}}
 if err:=cmd.Start();err!=nil{return childResult{err:err}}
 if _,err:=stdin.Write(input);err!=nil{cmd.Process.Kill();cmd.Wait();return childResult{err:err}}
 if closeAfter{stdin.Close()}
 wait:=make(chan error,1)
 go func(){wait<-cmd.Wait()}()
 var result childResult
 select{
 case err:=<-wait:
  if err==nil{result.exit=0
  }else{
   var e *exec.ExitError
   if !errors.As(err,&e){result.err=err}else{result.exit=e.ExitCode()}
  }
 case <-time.After(1800*time.Millisecond):
  cmd.Process.Kill()
  <-wait
  result.err=fmt.Errorf("synthetic child did not exit promptly")
 }
 result.elapsed=time.Since(start)
 result.output=append([]byte(nil),stdout.Bytes()...)
 return result
}
func TestPendingStopAndEofCancelNativeChild(t *testing.T){
 for _,mode:=range []string{"stop","eof"}{
  t.Run(mode,func(t *testing.T){
   for rep:=0;rep<12;rep++{
    cmd:=exec.Command(os.Args[0],"-test.run=^TestHostHelperProcess$")
    cmd.Env=append(os.Environ(),"R079_HELPER=1")
    var output bytes.Buffer
    cmd.Stdout=&output
    stdin,e:=cmd.StdinPipe()
    if e!=nil{t.Fatal(e)}
    if e:=cmd.Start();e!=nil{t.Fatal(e)}
    request:=wire(message{Kind:"request",ID:"pending-approval",Tab:"synthetic-A",Generation:"g1"})
    if _,e:=stdin.Write(request);e!=nil{cmd.Process.Kill();cmd.Wait();t.Fatal(e)}
    time.Sleep(25*time.Millisecond)
    start:=time.Now()
    if mode=="stop" {
     if _,e:=stdin.Write(wire(message{Kind:"stop"}));e!=nil{cmd.Process.Kill();cmd.Wait();t.Fatal(e)}
    }
    stdin.Close()
    wait:=make(chan error,1)
    go func(){wait<-cmd.Wait()}()
    select {
    case e:=<-wait:
     if e!=nil{t.Fatalf("%s native child exited with error: %v",mode,e)}
    case <-time.After(1400*time.Millisecond):
     cmd.Process.Kill();<-wait;t.Fatal("child did not exit on Stop/disconnect")
    }
    if len(output.Bytes())!=0{t.Fatalf("late output after Stop/disconnect (rep %d): %x",rep,output.Bytes())}
    if time.Since(start)>1400*time.Millisecond{t.Fatal("slow shutdown")}
   }
  })
 }
}
func TestRawWriteAndUnknownOperationsAlwaysDeny(t *testing.T){
 for _,typ:=range []string{"raw-write","read-adjacent-tab","approval-spoof","UNKNOWN"}{
  r:=invoke(wire(message{Kind:typ,ID:"probe",Tab:"synthetic-B",Generation:"g999"}),true)
  if r.err!=nil||r.exit!=0{t.Fatalf("%s: %+v",typ,r)}
  answers:=decodeReplies(t,r.output)
  if len(answers)!=1||answers[0].Result!="DENY"||answers[0].Reason!="no-authority"{
   t.Fatalf("%s incorrectly admitted: %#v",typ,answers)
  }
 }
}
func TestMalformedNativeMessageExitsWithoutReply(t *testing.T){
 cases:=map[string][]byte{
  "over-limit":{0x01,0x10,0x00,0x00},
  "partial-prefix":{0x01,0x10},
  "missing-body":{0x20,0x00,0x00,0x00,0x7b},
  "zero-frame":{0x00,0x00,0x00,0x00},
 }
 for name,data:=range cases{t.Run(name,func(t *testing.T){
  r:=invoke(data,true)
  if r.err!=nil||r.exit!=2||len(r.output)!=0{
   t.Fatalf("unsafe malformed-frame behavior: %+v",r)
  }
 })}
}
func TestUnknownJsonFieldAndTrailingContentDenied(t *testing.T){
 for _,body:=range []string{
  `{"kind":"raw-write","cookie":"synthetic"}`,
  `{"kind":"raw-write"} {"kind":"stop"}`,
 }{
  var prefix [4]byte
  binary.LittleEndian.PutUint32(prefix[:],uint32(len(body)))
  r:=invoke(append(prefix[:],[]byte(body)...),true)
  if r.err!=nil||r.exit!=2||len(r.output)!=0{t.Fatalf("invalid JSON passed: %+v",r)}
 }
}
func TestReconnectDoesNotCreateImplicitGrant(t *testing.T){
 first:=invoke(append(wire(message{Kind:"request",ID:"old",Generation:"g1"}),wire(message{Kind:"stop"})...),true)
 if first.err!=nil||first.exit!=0||len(first.output)!=0{t.Fatal("Stop left output or child")}
 second:=invoke(wire(message{Kind:"raw-write",ID:"old",Generation:"g1",Tab:"synthetic-A"}),true)
 if second.err!=nil||second.exit!=0{t.Fatal("new child failed")}
 got:=decodeReplies(t,second.output)
 if len(got)!=1||got[0].Result!="DENY"{t.Fatalf("stale grant silently survived reconnect: %#v",got)}
}
func TestPendingStillCannotBeConvertedToApproval(t *testing.T){
 input:=append(wire(message{Kind:"request",ID:"pending"}),wire(message{Kind:"approval-spoof",ID:"evil"})...)
 r:=invoke(input,true)
 if r.err!=nil||r.exit!=0{t.Fatalf("process errored: %+v",r)}
 got:=decodeReplies(t,r.output)
 if len(got)!=1||got[0].Result!="DENY"||got[0].ID!="evil"{t.Fatalf("spoof admitted: %#v",got)}
}
func TestR079MatrixEnvironment(t *testing.T) {
 if runtime.GOOS!="windows" {t.Fatalf("requires actual Windows host: %s",runtime.GOOS)}
 if strings.TrimSpace(os.Getenv("GITHUB_ACTIONS"))!="true"{t.Fatal("qualification must execute in real GHA")}
 t.Logf("R079_SYNTHETIC_BOUNDARY=windows/%s; browser_hil=false; private_source=false; promotion_authorized=false",runtime.GOARCH)
}
