// MallGuard 商场多媒体与应急显示终端 · Windows控制台
// 职责：S20/S21/S23/S25/S27状态协议解析、XOR校验与命令目标判断。最终FPGA回传S25。
// 保留V5.1类/方法标识以兼容现有测试，文件名按产品职责组织。
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;

namespace MallDisplayConsole {
    public sealed class BoardState {
        public int Slot,VideoFlags,VideoFrame,VideoError;
        public int LoadStage,LoadFile,LoadError,LoadElapsedSeconds;
        public bool HasLoadDetail {get{return Version>=27;}}
        public int LoadFlags,LoadProgress,ReceiptSequence,ReceiptCommand,ReceiptStatus,ConfigFlags,ManualCounter;
        public bool Loading {get{return (LoadFlags&1)!=0;}}
        public bool CachedFrame {get{return (LoadFlags&2)!=0;}}
        public bool LoadFailed {get{return (LoadFlags&4)!=0;}}
        public bool ConfigBusy {get{return (ConfigFlags&1)!=0;}}
        public bool SaveComplete {get{return (ConfigFlags&2)!=0;}}
        public bool VideoMode {get{return (VideoFlags&1)!=0;}}
        public bool VideoLoaded {get{return (VideoFlags&4)!=0;}}
        public bool VideoPlaying {get{return (VideoFlags&8)!=0;}}
        public bool VideoBuffering {get{return (VideoFlags&16)!=0;}}
        public int Version=20,NoticeKind,NoticeId,NoticeFlags,NoticeError;
        public int Sequence, Picture, PeriodMs, Volume, Brightness, Error, Emergency, ReadyMask, ConfigVolume, ConfigBrightness;
        public bool Auto, BootReady;
        public DateTime ReceivedUtc;
        public BoardState Copy() { return (BoardState)MemberwiseClone(); }
    }
    public sealed class LegacyUpdate {
        public string Kind; public int Value; public bool Auto;
    }
    public static class Protocol {
        public static readonly string[] Starts = { "", "fire", "power_outage", "incident", "doctor" };
        public static readonly string[] Ends = { "", "put_out", "power_back", "security", "safe" };
        public static readonly string[] Names = { "普通播放", "火灾警报", "停电事件", "治安事件", "医疗求助" };
        public static readonly string[] Images = { "", "FIRE.BMP", "POWER.BMP", "SECURITY.BMP", "MEDICAL.BMP" };
        public static int Percent(int raw) { return (int)Math.Round(raw * 100.0 / 255.0, MidpointRounding.AwayFromZero); }
        public static byte Checksum(string payload) {
            byte result=0; foreach(char c in payload) { if(c>127) throw new FormatException("状态包含非ASCII字符"); result^=(byte)c; } return result;
        }
        static int Hex(string s,int digits) {
            int v; if(s.Length!=digits || !Int32.TryParse(s,NumberStyles.AllowHexSpecifier,CultureInfo.InvariantCulture,out v)) throw new FormatException("十六进制字段格式错误"); return v;
        }
        public static bool TryState(string line, out BoardState state, out string reason) {
            state=null; reason=null;
            bool v27=line.StartsWith("@S27,",StringComparison.Ordinal);bool v25=v27||line.StartsWith("@S25,",StringComparison.Ordinal);bool v23=v25||line.StartsWith("@S23,",StringComparison.Ordinal);bool v21=v23||line.StartsWith("@S21,",StringComparison.Ordinal);if(!v21&&!line.StartsWith("@S20,",StringComparison.Ordinal)) return false;
            try {
                int payloadLength=v27?97:v25?83:v23?62:v21?51:40;
                if(line.Length!=payloadLength+3 || line[payloadLength]!='*') throw new FormatException("状态包长度错误");
                string payload=line.Substring(0,payloadLength);
                if(Checksum(payload)!=Hex(line.Substring(payloadLength+1,2),2)) throw new FormatException("状态包校验失败");
                string[] f=payload.Split(','); if(f.Length!=(v27?32:v25?28:v23?21:v21?17:13)) throw new FormatException("状态字段数错误");
                BoardState s=new BoardState();
                if(v21){s.Version=21;s.NoticeKind=Hex(f[13],1);s.NoticeId=Hex(f[14],4);s.NoticeFlags=Hex(f[15],1);s.NoticeError=Hex(f[16],1);if(s.NoticeKind>2)throw new FormatException("通知类型无效");}
                if(v23){s.Version=23;s.Slot=Hex(f[17],1);s.VideoFlags=Hex(f[18],2);s.VideoFrame=Hex(f[19],2);s.VideoError=Hex(f[20],2);if(s.Slot>3||s.VideoFrame>=160)throw new FormatException("视频或时段字段无效");}
                if(v25){s.Version=25;s.LoadFlags=Hex(f[21],2);s.LoadProgress=Hex(f[22],2);s.ReceiptSequence=Hex(f[23],2);s.ReceiptCommand=Hex(f[24],2);s.ReceiptStatus=Hex(f[25],2);s.ConfigFlags=Hex(f[26],2);s.ManualCounter=Hex(f[27],2);if(s.LoadProgress>100||s.ReceiptStatus>5||(s.ConfigFlags&0xf0)!=0||(s.LoadFlags&0xf8)!=0)throw new FormatException("扩展状态字段无效");}
                if(v27){s.Version=27;s.LoadStage=Hex(f[28],2);s.LoadFile=Hex(f[29],2);s.LoadError=Hex(f[30],2);s.LoadElapsedSeconds=Hex(f[31],4);if(s.LoadStage>9||!(s.LoadFile<=4||s.LoadFile>=17&&s.LoadFile<=20))throw new FormatException("加载详情字段无效");}
                s.Sequence=Hex(f[1],4); s.Picture=Hex(f[2],1);
                if(s.Picture<1 || s.Picture>4 || (f[3]!="A" && f[3]!="E")) throw new FormatException("图片或模式字段无效");
                s.Auto=f[3]=="A"; s.PeriodMs=Hex(f[4],5); s.Volume=Hex(f[5],2); s.Brightness=Hex(f[6],2);
                s.Error=Hex(f[7],2); s.Emergency=Hex(f[8],1); s.ReadyMask=Hex(f[9],1);
                if(f[10]!="0" && f[10]!="1") throw new FormatException("启动状态无效");
                s.BootReady=f[10]=="1"; s.ConfigVolume=Hex(f[11],2); s.ConfigBrightness=Hex(f[12],2);
                if(s.Emergency>4 || s.PeriodMs<=0) throw new FormatException("应急或间隔字段无效");
                if(s.Emergency!=0 && (s.Brightness!=255 || s.Volume!=(s.Emergency==2?0:255))) throw new FormatException("应急输出值不一致");
                if(s.Emergency==0 && (s.Volume!=s.ConfigVolume || s.Brightness!=s.ConfigBrightness)) throw new FormatException("普通输出与广告配置不一致");
                s.ReceivedUtc=DateTime.UtcNow; state=s; return true;
            } catch(FormatException e) { reason=e.Message; return false; }
        }
        public static bool TryLegacy(string line,out LegacyUpdate update) {
            update=null;
            string[] p=line.Split(new char[]{' '},StringSplitOptions.RemoveEmptyEntries); int v;
            if(p.Length==3 && p[0]=="PIC" && Int32.TryParse(p[1],out v) && v>=1 && v<=4 && (p[2]=="A" || p[2]=="M")) {
                update=new LegacyUpdate {Kind="PIC",Value=v,Auto=p[2]=="A"};return true;
            }
            if(p.Length==2 && (p[0]=="VOL" || p[0]=="BRT" || p[0]=="ERR") && p[1].Length==2 && Int32.TryParse(p[1],NumberStyles.AllowHexSpecifier,CultureInfo.InvariantCulture,out v)) {
                update=new LegacyUpdate {Kind=p[0],Value=v};return true;
            }
            if(p.Length==2 && p[0]=="PRD" && p[1].Length==7 && p[1].EndsWith("ms",StringComparison.Ordinal) && Int32.TryParse(p[1].Substring(0,5),NumberStyles.AllowHexSpecifier,CultureInfo.InvariantCulture,out v) && v>0) {
                update=new LegacyUpdate{Kind="PRD",Value=v};return true;
            }
            return false;
        }
        public static string Frame(BoardState s) {
            string payload=String.Format(CultureInfo.InvariantCulture,"@S20,{0:X4},{1},{2},{3:X5},{4:X2},{5:X2},{6:X2},{7},{8:X1},{9},{10:X2},{11:X2}",
                s.Sequence&65535,s.Picture,s.Auto?"A":"E",s.PeriodMs,s.Volume,s.Brightness,s.Error,s.Emergency,s.ReadyMask,s.BootReady?1:0,s.ConfigVolume,s.ConfigBrightness);
            if(s.Version>=21)payload="@S21"+payload.Substring(4)+String.Format(CultureInfo.InvariantCulture,",{0},{1:X4},{2:X1},{3:X1}",s.NoticeKind,s.NoticeId&65535,s.NoticeFlags,s.NoticeError);
            if(s.Version>=23)payload="@S23"+payload.Substring(4)+String.Format(CultureInfo.InvariantCulture,",{0:X1},{1:X2},{2:X2},{3:X2}",s.Slot,s.VideoFlags,s.VideoFrame,s.VideoError);
            if(s.Version>=25)payload="@S25"+payload.Substring(4)+String.Format(CultureInfo.InvariantCulture,",{0:X2},{1:X2},{2:X2},{3:X2},{4:X2},{5:X2},{6:X2}",s.LoadFlags,s.LoadProgress,s.ReceiptSequence,s.ReceiptCommand,s.ReceiptStatus,s.ConfigFlags,s.ManualCounter);
            if(s.Version>=27)payload="@S27"+payload.Substring(4)+String.Format(CultureInfo.InvariantCulture,",{0:X2},{1:X2},{2:X2},{3:X4}",s.LoadStage,s.LoadFile,s.LoadError,s.LoadElapsedSeconds);
            return payload+"*"+Checksum(payload).ToString("X2",CultureInfo.InvariantCulture)+"\r\n";
        }
        public static bool CommandTarget(string command,out int target,out bool ending) {
            for(int i=1;i<=4;i++) { if(command==Starts[i]) {target=i;ending=false;return true;} if(command==Ends[i]) {target=0;ending=true;return true;} }
            target=-1;ending=false;return false;
        }
        public static int CommandCode(string text) {
            text=(text??"").Trim().ToLowerInvariant();string verb=text.Split(' ')[0];
            string[] names={"","video","ads","pause","play","next","prev","auto","manual","vol","light","interval","slot","save"};
            for(int i=1;i<names.Length;i++)if(verb==names[i])return i;
            for(int i=1;i<=4;i++){if(text==Starts[i])return 0x20+i*2;if(text==Ends[i])return 0x21+i*2;}
            return -1;
        }
        public static string ReceiptReason(int status) {
            switch(status){case 0:return "开发板已接受";case 1:return "设备忙碌，未执行";case 2:return "当前界面或事件不允许此操作";case 3:return "配置服务尚未就绪";case 4:return "参数无效";case 5:return "已排队，等待广告界面可切换";default:return "未知回执";}
        }
        public static string VideoErrorName(int code) {
            switch(code){case 0:return "无视频错误";case 0xA2:return "TF卡缺少VIDEO.BIN";case 0xA3:return "视频文件大小不匹配";case 0xA5:return "视频包CRC错误";case 0xA6:return "视频输入FIFO溢出";case 0xA7:return "视频文件头不匹配";case 0xC1:return "SDRAM事务超时";case 0xC2:return "写FIFO欠载";case 0xD1:return "补缓冲超过3秒";case 0xD2:return "视频解码落后音频";default:return "检查TF卡与视频文件";}
        }
        public static string LoadStageName(int stage) {
            string[] names={"空闲","淡出 / 结束旧读取","复制上一完整画面至缓存","保持缓存画面","SD初始化 / FAT目录扫描","读取BMP文件","装载四图素材组","提交新画面","应急 / 广播优先，加载暂停","加载失败"};
            return stage>=0&&stage<names.Length?names[stage]:"未知阶段";
        }
        public static string LoadFileName(BoardState s) {
            if(!s.HasLoadDetail)return "未上报";
            if(s.LoadFile==0)return "无当前文件";
            if(s.LoadFile>=1&&s.LoadFile<=4)return new[]{"PIC","MOR","DAY","EVE"}[s.Slot]+s.LoadFile+".BMP";
            return s.LoadFile>=17&&s.LoadFile<=20?Images[s.LoadFile-16]:"未知文件";
        }
        public static string LoadErrorName(int code) {
            switch(code){case 0:return "无底层错误";case 1:return "SD响应超时";case 2:return "SD读命令被拒绝";case 3:return "SD数据令牌超时";case 4:return "SD数据令牌错误";case 5:return "SD CRC16不匹配";case 6:return "SD未初始化";case 7:return "SD停止命令失败";case 15:return "SD读取状态无效";
             case 0x20:return "FAT启动签名错误";case 0x21:return "FAT BPB不支持";case 0x22:return "必需文件缺失";case 0x23:return "FAT簇链循环";case 0x24:return "FAT簇号无效";case 0x25:return "FAT过早结束";case 0x26:return "FAT遍历上限";case 0x27:return "文件大小错误";
             case 0x31:return "BMP标识错误";case 0x32:return "BMP尺寸不支持";case 0x33:return "BMP平面数错误";case 0x34:return "BMP位深不支持";case 0x35:return "BMP压缩不支持";case 0x36:return "BMP像素偏移错误";case 0x37:return "BMP数据截断";case 0x38:return "BMP上游读取失败";case 0xE1:return "SD重放捕获顺序或长度错误";default:return "底层错误（保留原码）";}
        }
        public static string LoadDetail(BoardState s) {
            if(s==null)return "等待实时状态";
            if(!s.HasLoadDetail)return (s.Version>=25?"加载 "+s.LoadProgress+"% · E"+s.Error.ToString("X2"):"E"+s.Error.ToString("X2"))+"；此协议未上报阶段 / 文件 / 底层码 / 耗时";
            return "LS"+s.LoadStage.ToString("X2")+" "+LoadStageName(s.LoadStage)+" · FI"+s.LoadFile.ToString("X2")+" "+LoadFileName(s)+" · LE"+s.LoadError.ToString("X2")+" "+LoadErrorName(s.LoadError)+" · E"+s.Error.ToString("X2")+" · "+s.LoadElapsedSeconds+"秒";
        }
        public static string ErrorName(int code) {
            switch(code) {
                case 0:return "未报告错误";case 0x22:return "广告资源缺失";case 0x31:return "BMP文件标识错误";
                case 0x32:return "BMP尺寸不支持";case 0x34:return "BMP位深不支持";case 0x35:return "BMP压缩格式不支持";
                case 0x61:return "读帧重叠";case 0x62:return "读FIFO溢出";case 0x63:return "视频数据欠载";case 0x64:return "读帧不完整";
                case 0x71:return "音频链路错误";default:return "板端错误，请查看原始日志";
            }
        }
    }
    public sealed class LineAssembler {
        readonly StringBuilder line=new StringBuilder(); bool dropping;
        public int DroppedLines {get;private set;}
        public void Reset() {line.Length=0;dropping=false;DroppedLines=0;}
        public List<string> Feed(byte[] bytes) {
            List<string> result=new List<string>();
            foreach(byte b in bytes) {
                if(b==10 || b==13) { if(!dropping && line.Length>0) result.Add(line.ToString()); line.Length=0;dropping=false; }
                else if(!dropping) { if(line.Length>=512) {dropping=true;line.Length=0;DroppedLines++;} else line.Append((char)b); }
            }
            return result;
        }
    }
    public sealed class PendingCommand {
        public string Text; public int Target; public DateTime SentUtc; public int? PreviousSequence;
        public Func<BoardState,bool> Expected;
        public int CommandCode=-1;public int? PreviousReceipt;public bool Accepted,LoadingSeen,SlotRestartObserved;
        // A stable-reload firmware intentionally resets UART/receipt counters.
        // Preserve only a pending slot request whose NEW boot reports the
        // requested group, then confirm after the board reports boot complete.
        public bool ObserveSlotRestart(BoardState state){
            int slot;
            if(CommandCode!=12||Text==null||!Text.StartsWith("slot ",StringComparison.Ordinal)||
               !Int32.TryParse(Text.Substring(5),out slot)||slot<0||slot>3||state.Version<25||
               state.BootReady||state.Emergency!=0||state.Slot!=slot||state.ReceivedUtc<SentUtc||
               (state.ReceivedUtc-SentUtc).TotalSeconds>TimeoutSeconds)return false;
            SlotRestartObserved=true;LoadingSeen=true;Accepted=true;return true;
        }
        public double TimeoutSeconds {get{return Text!=null&&Text.StartsWith("slot ",StringComparison.Ordinal)?45:Text=="save"?15:3;}}
        public bool ReceiptMatches(BoardState state){return state.Version>=25&&CommandCode>=0&&state.ReceivedUtc>=SentUtc&&(!PreviousSequence.HasValue||state.Sequence!=PreviousSequence.Value)&&(PreviousReceipt.HasValue&&state.ReceiptSequence!=PreviousReceipt.Value)&&state.ReceiptCommand==CommandCode;}
        public void Observe(BoardState state){if(ReceiptMatches(state)&&state.Loading)LoadingSeen=true;}
        public bool Rejected(BoardState state){return ReceiptMatches(state)&&state.ReceiptStatus!=0&&state.ReceiptStatus!=5;}
        public bool Matched(BoardState state) { if(SlotRestartObserved)return CommandCode==12&&state.BootReady&&state.Error==0&&!state.Loading&&!state.CachedFrame&&!state.LoadFailed&&state.ReceivedUtc>=SentUtc&&Expected!=null&&Expected(state);return (!(state.Version>=25&&CommandCode==12)||LoadingSeen&&!state.Loading&&!state.CachedFrame&&!state.LoadFailed) && (state.Version<25||CommandCode<0||(ReceiptMatches(state)&&!Rejected(state))) && state.ReceivedUtc>=SentUtc && (Expected!=null?Expected(state):state.Emergency==Target) && (!PreviousSequence.HasValue || state.Sequence!=PreviousSequence.Value); }
    }
}
