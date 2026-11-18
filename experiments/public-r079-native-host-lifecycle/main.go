// Public-owned synthetic native-messaging transport lifecycle oracle.
// No browser, extension, registry, credential, actual native host, or user session.
package main

import (
 "bytes"
 "encoding/binary"
 "encoding/json"
 "errors"
 "fmt"
 "io"
 "os"
 "strings"
 "time"
)

const maxFrameBytes = 4096
const pendingDeadline = 850 * time.Millisecond

type message struct {
 Kind string `json:"kind"`
 ID string `json:"id,omitempty"`
 Generation string `json:"generation,omitempty"`
 Tab string `json:"tab,omitempty"`
}
type reply struct {
 Kind string `json:"kind"`
 ID string `json:"id,omitempty"`
 Result string `json:"result"`
 Reason string `json:"reason"`
}
type frame struct { msg message; err error }

func readFrame(r io.Reader) (message,error) {
 var m message
 var prefix [4]byte
 if _,err:=io.ReadFull(r,prefix[:]);err!=nil{return m,err}
 n:=binary.LittleEndian.Uint32(prefix[:])
 if n<2||n>maxFrameBytes {return m,errors.New("refused oversized or empty input frame")}
 b:=make([]byte,int(n))
 if _,err:=io.ReadFull(r,b);err!=nil{return m,err}
 dec:=json.NewDecoder(bytes.NewReader(b))
 dec.DisallowUnknownFields()
 if err:=dec.Decode(&m);err!=nil{return m,err}
 if _,err:=dec.Token();err!=io.EOF{return m,errors.New("trailing JSON content")}
 if m.Kind==""||len(m.Kind)>40||strings.ContainsAny(m.Kind,"\x00\r\n"){return m,errors.New("invalid message type")}
 return m,nil
}
func sendReply(w io.Writer,value reply)error{
 b,err:=json.Marshal(value);if err!=nil{return err}
 if len(b)>maxFrameBytes{return errors.New("reply too large")}
 var prefix [4]byte
 binary.LittleEndian.PutUint32(prefix[:],uint32(len(b)))
 if _,err:=w.Write(prefix[:]);err!=nil{return err}
 _,err=w.Write(b);return err
}
func run(r io.Reader,w io.Writer)int{
 incoming:=make(chan frame,1)
 go func(){
  defer close(incoming)
  for {
   m,e:=readFrame(r)
   incoming<-frame{msg:m,err:e}
   if e!=nil{return}
  }
 }()
 var activeID string
 var timer *time.Timer
 var expired <-chan time.Time
 defer func(){if timer!=nil{timer.Stop()}}()
 for{
  select{
  case event,ok:=<-incoming:
   if !ok{return 0}
   if event.err!=nil{
    if errors.Is(event.err,io.EOF){return 0} // browser disconnect: stop all pending work
    return 2 // malformed frame: fail closed, never wait for pending reply
   }
   switch event.msg.Kind{
   case "stop":
    return 0 // Stop terminates before a delayed native authorization response
   case "request":
    if activeID!=""{
     if sendReply(w,reply{Kind:"result",ID:event.msg.ID,Result:"DENY",Reason:"pending-request-exists"})!=nil{return 2}
     continue
    }
    // No operator approval exists in this synthetic workcell.
    activeID=event.msg.ID
    timer=time.NewTimer(pendingDeadline)
    expired=timer.C
   default:
    // Raw writes and unknown requests can never be admitted by this stand-in.
    if sendReply(w,reply{Kind:"result",ID:event.msg.ID,Result:"DENY",Reason:"no-authority"})!=nil{return 2}
   }
  case <-expired:
   if activeID!=""{
    if sendReply(w,reply{Kind:"result",ID:activeID,Result:"DENY",Reason:"no-operator-approval"})!=nil{return 2}
   }
   activeID=""
   expired=nil
   timer=nil
  }
 }
}
func main(){
 if status:=run(os.Stdin,os.Stdout);status!=0 {
  fmt.Fprintln(os.Stderr,"SYNTHETIC_NATIVE_HOST_FAIL_CLOSED",status)
  os.Exit(status)
 }
}
