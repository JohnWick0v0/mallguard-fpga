// MallGuard 商场多媒体与应急显示终端 · Windows控制台
// 职责：串口收发线程及连接生命周期；事件交回主窗体进行UI同步。
// 保留V5.1类/方法标识以兼容现有测试，文件名按产品职责组织。
using System;
using System.IO.Ports;
using System.Threading;
using System.Collections.Generic;
using System.Management;

namespace MallDisplayConsole {
    public sealed class SerialSettings {
        public string Port=""; public int Baud=115200,DataBits=8; public string Parity="None",StopBits="One",Flow="None";
        public bool Dtr=false,Rts=false;
    }
    public sealed class PortChoice {
        public string Port,Name;
        public override string ToString(){return Name;}
    }
    public sealed class SerialLink:IDisposable {
        readonly object gate=new object(); SerialPort port; Thread reader; volatile bool stopping;
        public event Action<byte[]> Received; public event Action<string> Failed;
        public bool IsOpen {get {lock(gate) return port!=null && port.IsOpen && !stopping;}}
        public void Open(SerialSettings s) {
            lock(gate) {
                if(port!=null) throw new InvalidOperationException("串口已打开");
                SerialPort p=new SerialPort(s.Port,s.Baud,(Parity)Enum.Parse(typeof(Parity),s.Parity),s.DataBits,(StopBits)Enum.Parse(typeof(StopBits),s.StopBits));
                p.Handshake=(Handshake)Enum.Parse(typeof(Handshake),s.Flow);p.ReadTimeout=100;p.WriteTimeout=250;p.DtrEnable=s.Dtr;
                if(p.Handshake!=Handshake.RequestToSend && p.Handshake!=Handshake.RequestToSendXOnXOff)p.RtsEnable=s.Rts;
                try {p.Open();} catch {p.Dispose();throw;}
                port=p;stopping=false;
                reader=new Thread(delegate(){ReadLoop(p);});reader.IsBackground=true;reader.Name="FPGA-UART-RX";reader.Start();
            }
        }
        void ReadLoop(SerialPort p) {
            byte[] buffer=new byte[1024];
            while(!stopping) {
                try {int count=p.Read(buffer,0,buffer.Length);if(count>0 && !stopping){byte[] copy=new byte[count];Array.Copy(buffer,copy,count);Action<byte[]> h=Received;if(h!=null)h(copy);}}
                catch(TimeoutException){}
                catch(Exception e){if(!stopping){Action<string> h=Failed;if(h!=null)h(e.Message);}break;}
            }
        }
        public void Send(byte[] bytes) {lock(gate){if(port==null || !port.IsOpen || stopping)throw new InvalidOperationException("串口未连接");port.Write(bytes,0,bytes.Length);}}
        public void Dispose() {
            stopping=true;Thread t;
            lock(gate){if(port!=null){try{port.Close();}catch{}port.Dispose();port=null;}t=reader;reader=null;}
            if(t!=null && t!=Thread.CurrentThread)t.Join(500);
        }
        public static List<PortChoice> Ports() {
            Dictionary<string,string> names=new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);
            foreach(string p in SerialPort.GetPortNames())names[p]=p;
            try {
                using(ManagementObjectSearcher search=new ManagementObjectSearcher("SELECT Name FROM Win32_PnPEntity WHERE Name LIKE '%(COM%'"))
                using(ManagementObjectCollection values=search.Get())foreach(ManagementObject item in values) {
                    string name=Convert.ToString(item["Name"]);
                    foreach(string p in new List<string>(names.Keys))if(name.IndexOf("("+p+")",StringComparison.OrdinalIgnoreCase)>=0)names[p]=p+" · "+name.Substring(0,name.LastIndexOf("("+p+")",StringComparison.OrdinalIgnoreCase)).Trim();
                }
            } catch {}
            List<PortChoice> result=new List<PortChoice>();foreach(var item in names)result.Add(new PortChoice{Port=item.Key,Name=item.Value});
            result.Sort(delegate(PortChoice a,PortChoice b){return StringComparer.OrdinalIgnoreCase.Compare(a.Port,b.Port);});return result;
        }
    }
}
