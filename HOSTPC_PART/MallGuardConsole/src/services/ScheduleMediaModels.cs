// MallGuard 商场多媒体与应急显示终端 · Windows控制台
// 职责：时段、27项素材格式检查及实物观察判定模型，离线结果不作为实物验收。
// 保留V5.1类/方法标识以兼容现有测试，文件名按产品职责组织。
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Text;

namespace MallDisplayConsole {
 public sealed class SchedulePlan {
  public int Morning=7*60,Noon=11*60,Evening=17*60,Default=22*60;
  public bool IsValid {get{return Morning>=0&&Morning<Noon&&Noon<Evening&&Evening<Default&&Default<1440;}}
  public int SlotAt(DateTime local){if(!IsValid)throw new InvalidOperationException("四个时段起点必须按早间、午间、晚间、默认递增。");int m=local.Hour*60+local.Minute;return m<Morning||m>=Default?0:m<Noon?1:m<Evening?2:3;}
 }
 public sealed class MediaItem {
  public string Name,Group,Status,Detail;public bool Valid;public long Bytes;
 }
 public static class MediaLibrary {
  public static readonly string[] Prefixes={"PIC","MOR","DAY","EVE"};
  public static readonly string[] Music={"MUSIC.WAV","MORN.WAV","NOON.WAV","EVEN.WAV"};
  public static string[] Required(){List<string> n=new List<string>();foreach(string p in Prefixes)for(int i=1;i<=4;i++)n.Add(p+i+".BMP");n.AddRange(Music);n.AddRange(new[]{"FIRE.BMP","POWER.BMP","SECURITY.BMP","MEDICAL.BMP","ALARM.WAV","LOST.WAV","VIDEO.BIN"});return n.ToArray();}
  static int I32(byte[] b,int i){return BitConverter.ToInt32(b,i);}
  static uint U32(byte[] b,int i){return BitConverter.ToUInt32(b,i);}
  static ushort U16(byte[] b,int i){return BitConverter.ToUInt16(b,i);}
  public static MediaItem Check(string folder,string name){
   MediaItem r=new MediaItem{Name=name,Group=Array.IndexOf(Music,name)>=0?"背景音乐":name=="VIDEO.BIN"?"视频":name=="ALARM.WAV"||name=="LOST.WAV"?"广播/警报":"图片"};
   string p=Path.Combine(folder,name);
   try{
    if(!File.Exists(p))throw new InvalidDataException("文件缺失");
    FileInfo f=new FileInfo(p);r.Bytes=f.Length;
    if(f.Length>UInt32.MaxValue)throw new InvalidDataException("超过 FAT32 单文件大小");
    byte[] h=new byte[64];using(FileStream s=File.OpenRead(p)){if(s.Read(h,0,h.Length)<44)throw new InvalidDataException("文件头不完整");}
    if(name.EndsWith(".WAV",StringComparison.OrdinalIgnoreCase)){
     if(Encoding.ASCII.GetString(h,0,4)!="RIFF"||Encoding.ASCII.GetString(h,8,8)!="WAVEfmt "||U32(h,16)!=16||U16(h,20)!=1||U16(h,22)!=1||U32(h,24)!=48000||U32(h,28)!=96000||U16(h,32)!=2||U16(h,34)!=16||Encoding.ASCII.GetString(h,36,4)!="data")throw new InvalidDataException("需标准44字节头、48kHz/16位/单声道PCM WAV");
     uint bytes=U32(h,40);if(bytes==0||(bytes&1)!=0||bytes>f.Length-44||U32(h,4)>f.Length-8)throw new InvalidDataException("WAV 长度与采样对齐错误");
     r.Detail=(bytes/96000.0).ToString("0.00",CultureInfo.InvariantCulture)+" 秒 · PCM16 / 48k / mono";
    }else if(name.EndsWith(".BMP",StringComparison.OrdinalIgnoreCase)){
     if(h[0]!='B'||h[1]!='M'||I32(h,18)!=640||Math.Abs((long)I32(h,22))!=480||U16(h,26)!=1||U16(h,28)!=24||U32(h,30)!=0)throw new InvalidDataException("需640×480、24位、无压缩BMP");
     uint offset=U32(h,10);if(offset<54||offset>4096||U32(h,14)<40||offset+921600L>f.Length)throw new InvalidDataException("BMP 数据偏移或长度错误");
     r.Detail="640×480 · RGB24 · BI_RGB";
    }else{
     if(Encoding.ASCII.GetString(h,0,8)!="BC1AV001"||U32(h,8)!=1||U32(h,12)!=640||U32(h,16)!=480||U32(h,20)!=640||U32(h,24)!=360||U32(h,28)!=60||U32(h,32)!=10||U32(h,36)!=160||U32(h,40)!=48000||U32(h,44)!=4800||U32(h,48)!=124928||U32(h,52)!=115200||U32(h,56)!=9600||U32(h,60)!=19988992||f.Length!=19988992)throw new InvalidDataException("VIDEO.BIN 不符合当前160帧/10fps配套布局");
     r.Detail="640×480 输出 · 10fps · 16秒 · 文件头通过；完整CRC需板端/离线校验";
    }
    r.Valid=true;r.Status="通过";
   }catch(Exception e){r.Valid=false;r.Status=File.Exists(p)?"格式错误":"缺失";r.Detail=e.Message;}
   return r;
  }
  public static List<MediaItem> Scan(string folder){List<MediaItem> r=new List<MediaItem>();foreach(string n in Required())r.Add(Check(folder,n));return r;}
 }
 public sealed class Observation {
  public DateTime StartedUtc,LastUtc;public long Frames;public int EmergencyEntered,EmergencyExited,Slots,Notices,VideoSeen,ErrorFrames,InvalidFrames,ConnectionLosses;
  public double MaxGap;public bool Demo;int lastEmergency;int? lastSequence;bool lastBoot;public int BoardRestarts,LostFrames;readonly Stopwatch elapsedWatch=new Stopwatch();
  public double ElapsedSeconds {get{return elapsedWatch.Elapsed.TotalSeconds;}}
  public bool Running;
  public void Start(DateTime now,bool demo){StartedUtc=now;LastUtc=DateTime.MinValue;Frames=0;EmergencyEntered=EmergencyExited=Slots=Notices=VideoSeen=ErrorFrames=InvalidFrames=ConnectionLosses=0;MaxGap=0;Demo=demo;lastEmergency=0;lastSequence=null;lastBoot=false;BoardRestarts=LostFrames=0;elapsedWatch.Restart();Running=true;}
  public void Feed(BoardState s){
   if(!Running)return;
   if(lastSequence.HasValue){int delta=(s.Sequence-lastSequence.Value)&65535;if(delta==0){InvalidFrames++;return;}bool restarted=delta>32768||(lastBoot&&!s.BootReady);if(restarted)BoardRestarts++;else if(delta>1)LostFrames+=delta-1;}
   lastSequence=s.Sequence;lastBoot=s.BootReady;
   MaxGap=Math.Max(MaxGap,(s.ReceivedUtc-(LastUtc==DateTime.MinValue?StartedUtc:LastUtc)).TotalSeconds);LastUtc=s.ReceivedUtc;Frames++;Slots|=1<<s.Slot;Notices|=1<<s.NoticeKind;if(s.VideoMode&&s.VideoPlaying)VideoSeen=1;if(s.Emergency!=0)EmergencyEntered|=1<<(s.Emergency-1);if(lastEmergency!=0&&s.Emergency==0)EmergencyExited|=1<<(lastEmergency-1);lastEmergency=s.Emergency;if(s.Error!=0||s.VideoError!=0||s.LoadFailed||s.HasLoadDetail&&s.LoadError!=0)ErrorFrames++;
  }
  public bool MeetsCriteria(double elapsed,double gap,bool coverage){return !Demo&&elapsed>=7200&&Frames>0&&ErrorFrames==0&&InvalidFrames==0&&ConnectionLosses==0&&BoardRestarts==0&&LostFrames==0&&gap<=2&&coverage;}

  public object Summary(DateTime now){double elapsed=ElapsedSeconds;double gap=LastUtc==DateTime.MinValue?elapsed:(now-LastUtc).TotalSeconds;double maxGap=Math.Max(MaxGap,gap);bool coverage=EmergencyEntered==15&&EmergencyExited==15&&Slots==15&&(Notices&6)==6&&VideoSeen==1;
   return new{mode=Demo?"offline_demo":"physical_serial",started_utc=StartedUtc,elapsed_seconds=elapsed,valid_frames=Frames,error_frames=ErrorFrames,invalid_frames=InvalidFrames,connection_losses=ConnectionLosses,board_restarts=BoardRestarts,lost_frames=LostFrames,max_gap_seconds=maxGap,monotonic_timer=true,emergency_enter_mask=EmergencyEntered,emergency_exit_mask=EmergencyExited,slot_mask=Slots,notice_mask=Notices,video_seen=VideoSeen,coverage_complete=coverage,two_hours_complete=elapsed>=7200,passed=MeetsCriteria(elapsed,maxGap,coverage)};}
 }
}
