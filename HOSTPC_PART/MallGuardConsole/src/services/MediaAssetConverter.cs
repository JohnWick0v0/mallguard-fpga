// MallGuard 商场多媒体与应急显示终端 · Windows控制台
// 职责：图片/四首背景音乐转换，临时目录验证后发布，覆盖前备份；不转换通用MP4。
// 保留V5.1类/方法标识以兼容现有测试，文件名按产品职责组织。
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Text;
using System.Web.Script.Serialization;

namespace MallDisplayConsole {
 public static class MediaConverter {
  static string Quote(string s){return "\""+s.Replace("\"","\\\"")+"\"";}
  static string F(double n){return n.ToString("0.########",CultureInfo.InvariantCulture);}
  static string Ffmpeg(string exe,string args){
   if(!File.Exists(exe))throw new FileNotFoundException("缺少 tools/ffmpeg.exe，请使用完整上位机包。",exe);
   using(Process p=new Process()){p.StartInfo=new ProcessStartInfo(exe,"-hide_banner -nostdin "+args){UseShellExecute=false,CreateNoWindow=true,RedirectStandardError=true};p.Start();string log=p.StandardError.ReadToEnd();p.WaitForExit();if(p.ExitCode!=0)throw new InvalidDataException(log.Length>1600?log.Substring(log.Length-1600):log);return log;}
  }
  static Dictionary<string,object> Loudness(string exe,string raw){string log=Ffmpeg(exe,"-f f32le -ar 48000 -ac 1 -i "+Quote(raw)+" -af loudnorm=I=-20:TP=-3:LRA=11:print_format=json -f null -");int a=log.LastIndexOf('{'),b=log.LastIndexOf('}');if(a<0||b<a)throw new InvalidDataException("未获得音频响度结果。");return new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(log.Substring(a,b-a+1));}
  static string Stage(string folder){Directory.CreateDirectory(folder);string p=Path.Combine(Path.GetFullPath(folder),".convert_"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(p);return p;}
  static void Publish(string staged,string folder,string name){
   string target=Path.Combine(Path.GetFullPath(folder),name);
   MediaItem check=MediaLibrary.Check(Path.GetDirectoryName(staged),name);if(!check.Valid)throw new InvalidDataException(check.Detail);
   if(File.Exists(target)){string backups=Path.Combine(folder,".media_backups");Directory.CreateDirectory(backups);File.Copy(target,Path.Combine(backups,DateTime.Now.ToString("yyyyMMdd_HHmmss_fff")+"_"+Guid.NewGuid().ToString("N").Substring(0,6)+"_"+name),false);}
   File.Copy(staged,target,true);
  }
  static void Clean(string stage){if(!Directory.Exists(stage))return;foreach(string f in Directory.GetFiles(stage))File.Delete(f);Directory.Delete(stage,false);}
  public static void Image(string source,string folder,string name){
   if(!name.EndsWith(".BMP",StringComparison.Ordinal)||Array.IndexOf(MediaLibrary.Required(),name)<0)throw new ArgumentException("请选择规定的图片文件名。");
   if(String.Equals(Path.GetFullPath(source),Path.GetFullPath(Path.Combine(folder,name)),StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("输出与源文件相同，请选择其他输出目录。");
   string stage=Stage(folder);
   try{using(Bitmap input=new Bitmap(source))using(Bitmap output=new Bitmap(640,480,PixelFormat.Format24bppRgb)){
     using(Graphics g=Graphics.FromImage(output)){g.Clear(Color.FromArgb(11,24,32));g.InterpolationMode=InterpolationMode.HighQualityBicubic;g.PixelOffsetMode=PixelOffsetMode.HighQuality;double scale=Math.Min(640.0/input.Width,480.0/input.Height);int w=Math.Max(1,(int)Math.Round(input.Width*scale)),h=Math.Max(1,(int)Math.Round(input.Height*scale));g.DrawImage(input,new Rectangle((640-w)/2,(480-h)/2,w,h));}
     output.Save(Path.Combine(stage,name),ImageFormat.Bmp);
    }Publish(Path.Combine(stage,name),folder,name);
   }finally{Clean(stage);}
  }
  public static void Audio(string exe,string source,string folder,string name,double start,int duration,bool seamless){
   if(Array.IndexOf(MediaLibrary.Music,name)<0)throw new ArgumentException("背景音乐只能输出为四个规定名称。");
   if(start<0||duration<10||duration>300)throw new ArgumentException("起点应为非负数，时长应为10～300秒。");
   if(String.Equals(Path.GetFullPath(source),Path.GetFullPath(Path.Combine(folder,name)),StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("输出与源文件相同，请选择其他输出目录。");
   string stage=Stage(folder),raw=Path.Combine(stage,"selected.f32"),loop=Path.Combine(stage,"loop.f32");int overlap=seamless?96000:0;
   try{
    Ffmpeg(exe,"-v error -y -ss "+F(start)+" -i "+Quote(source)+" -t "+F(duration+(seamless?2:0))+" -map 0:a:0 -vn -sn -dn -ac 1 -ar 48000 -acodec pcm_f32le -f f32le "+Quote(raw));
    byte[] bytes=File.ReadAllBytes(raw);int count=duration*48000;
    if(bytes.Length!=(count+overlap)*4)throw new InvalidDataException("源音频剩余长度不足；循环处理还需额外2秒素材。");
    float[] sourcePcm=new float[count+overlap],result=new float[count];Buffer.BlockCopy(bytes,0,sourcePcm,0,bytes.Length);
    if(seamless){Array.Copy(sourcePcm,overlap,result,0,count-overlap);for(int i=0;i<overlap;i++){double w=.5-.5*Math.Cos(Math.PI*i/(overlap-1));result[count-overlap+i]=(float)(sourcePcm[count+i]*(1-w)+sourcePcm[i]*w);}}
    else{Array.Copy(sourcePcm,result,count);for(int i=0;i<60000;i++)result[i]*=(float)Math.Pow(Math.Sin(Math.PI*.5*i/59999),2);for(int i=0;i<96000;i++)result[count-96000+i]*=(float)Math.Pow(Math.Cos(Math.PI*.5*i/95999),2);result[0]=result[count-1]=0;}
    bytes=new byte[count*4];Buffer.BlockCopy(result,0,bytes,0,bytes.Length);File.WriteAllBytes(loop,bytes);
    Dictionary<string,object> measure=Loudness(exe,loop);double integrated=Double.Parse(Convert.ToString(measure["input_i"],CultureInfo.InvariantCulture),CultureInfo.InvariantCulture),peak=Double.Parse(Convert.ToString(measure["input_tp"],CultureInfo.InvariantCulture),CultureInfo.InvariantCulture);
    if(Double.IsNaN(integrated)||Double.IsInfinity(integrated)||Double.IsInfinity(peak))throw new InvalidDataException("源音频静音或响度无效。");
    // A constant gain preserves natural dynamics and the continuous loop seam.
    double gain=Math.Pow(10,Math.Min(-20-integrated,-3-peak)/20);
    using(BinaryWriter w=new BinaryWriter(File.Create(Path.Combine(stage,name)))){
     w.Write(Encoding.ASCII.GetBytes("RIFF"));w.Write((uint)(36+count*2));w.Write(Encoding.ASCII.GetBytes("WAVEfmt "));w.Write((uint)16);w.Write((ushort)1);w.Write((ushort)1);w.Write((uint)48000);w.Write((uint)96000);w.Write((ushort)2);w.Write((ushort)16);w.Write(Encoding.ASCII.GetBytes("data"));w.Write((uint)(count*2));
     foreach(float sample in result){double scaled=sample*gain*32768;if(Double.IsNaN(scaled)||Double.IsInfinity(scaled)||scaled>32766||scaled<-32767)throw new InvalidDataException("音频存在非法采样或削波。");w.Write((short)Math.Round(scaled));}
    }
    Publish(Path.Combine(stage,name),folder,name);
   }finally{Clean(stage);}
  }
 }
}
