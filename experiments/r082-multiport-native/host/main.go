// Synthetic browser-launched native messaging host for the public R080 disposable Windows bake-off.
// NOT BrowserParity production code, does not read real browser state or user credentials.
package main

import (
 "bufio"
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

const maxNativeFrame=8192
type Input struct{
 Kind string `json:"kind"`
 Nonce string `json:"nonce,omitempty"`
}
type Output struct{
 Kind string `json:"kind"`
 Nonce string `json:"nonce"`
 Origin string `json:"origin"`
}
func audit(kind string, origin string) {
 path:=os.Getenv("R080_SYNTHETIC_AUDIT")
 if path=="" {return}
 f,e:=os.OpenFile(path,os.O_APPEND|os.O_WRONLY|os.O_CREATE,0600)
 if e!=nil{return}
 defer f.Close()
 b,_:=json.Marshal(map[string]string{"kind":kind,"origin":origin})
 fmt.Fprintln(f,string(b))
}
func readMessage(r *bufio.Reader)(Input,error){
 var m Input
 var nbytes [4]byte
 if _,e:=io.ReadFull(r,nbytes[:]);e!=nil{return m,e}
 n:=binary.LittleEndian.Uint32(nbytes[:])
 if n<2||n>maxNativeFrame{return m,errors.New("invalid native message length")}
 b:=make([]byte,n)
 if _,e:=io.ReadFull(r,b);e!=nil{return m,e}
 dec:=json.NewDecoder(bytes.NewReader(b))
 dec.DisallowUnknownFields()
 if e:=dec.Decode(&m);e!=nil{return m,e}
 if _,e:=dec.Token();e!=io.EOF{return m,errors.New("trailing JSON")}
 if m.Kind==""||len(m.Nonce)>80||strings.ContainsAny(m.Nonce,"\r\n\x00"){return m,errors.New("bad synthetic message")}
 return m,nil
}
func send(m Output)error{
 b,e:=json.Marshal(m);if e!=nil{return e}
 if len(b)>maxNativeFrame{return errors.New("response too large")}
 var h [4]byte
 binary.LittleEndian.PutUint32(h[:],uint32(len(b)))
 if _,e:=os.Stdout.Write(h[:]);e!=nil{return e}
 _,e=os.Stdout.Write(b)
 return e
}
func main(){
 origin:=""
 if len(os.Args)>1 {origin=os.Args[1]}
 if !strings.HasPrefix(origin,"chrome-extension://")||!strings.HasSuffix(origin,"/"){os.Exit(2)}
 audit("launch",origin)
 defer audit("exit",origin)
 messages:=make(chan struct{m Input;e error},1)
 go func(){
  reader:=bufio.NewReader(os.Stdin)
  for{
   m,e:=readMessage(reader)
   messages<-struct{m Input;e error}{m,e}
   if e!=nil{return}
  }
 }()
 // Delayed/no-op approval simulation; disconnect or browser shutdown must win over it.
 _=time.Now()
 for {
  item:=<-messages
  if item.e!=nil {return}
  switch item.m.Kind {
  case "ping":
   if e:=send(Output{Kind:"pong",Nonce:item.m.Nonce,Origin:origin});e!=nil{return}
  case "hold":
   // Intentionally emit no response. Next incoming browser EOF closes the native host.
  default:
   return
  }
 }
}
