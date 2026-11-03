// MallGuard 商场多媒体与应急显示终端 · Windows控制台
// 职责：用电脑字体栅格化400×304中文通知，生成CRC16并绑定UTF-8名称。
// 保留V5.1类/方法标识以兼容现有测试，文件名按产品职责组织。
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.Globalization;
using System.Text;
namespace MallDisplayConsole {
 public sealed class FinderPayload {
  public const int Width=400,Height=304,BytesPerRow=50;
  public int Kind,Id;public string Name;public byte[] Mask;public ushort MaskCrc,NameCrc;
  public static ushort Crc(byte[] data){ushort c=65535;foreach(byte b in data){c^=(ushort)(b<<8);for(int k=0;k<8;k++)c=(ushort)((c&32768)!=0?(c<<1)^0x1021:c<<1);}return c;}
  public static string ValidateName(string name){
   name=(name??"").Trim();byte[] utf8=new UTF8Encoding(false,true).GetBytes(name);
   int characters=new StringInfo(name).LengthInTextElements;
   if(characters<1||characters>16||utf8.Length>64)throw new ArgumentException("请输入1～16个字，UTF-8编码不超过64字节。");
   foreach(char c in name)if(Char.IsControl(c)||c=='"'||c=='“'||c=='”')throw new ArgumentException("名称不能包含换行、控制符或引号。");
   return name;
  }
  static void Text(Graphics g,string text,float size,FontStyle style,RectangleF box){
   using(Font f=new Font("Microsoft YaHei",size,style,GraphicsUnit.Pixel))using(StringFormat sf=new StringFormat(StringFormat.GenericTypographic)){sf.FormatFlags=StringFormatFlags.NoWrap;sf.Trimming=StringTrimming.None;g.DrawString(text,f,Brushes.White,box,sf);}
  }
  public static FinderPayload Create(int kind,string name,int id){
   if(kind!=1&&kind!=2)throw new ArgumentException("类型错误");
   name=ValidateName(name);FinderPayload p=new FinderPayload{Kind=kind,Name=name,Id=id&65535,Mask=new byte[15200]};
   using(Bitmap bitmap=new Bitmap(Width,Height,PixelFormat.Format24bppRgb)){
    using(Graphics g=Graphics.FromImage(bitmap)){
     g.Clear(Color.Black);g.TextRenderingHint=TextRenderingHint.AntiAliasGridFit;
     Text(g,kind==1?"寻人广播":"寻物广播",26,FontStyle.Bold,new RectangleF(26,20,280,36));
     float size=48;while(size>18){using(Font f=new Font("Microsoft YaHei",size,FontStyle.Bold,GraphicsUnit.Pixel))if(g.MeasureString(name,f).Width<=350)break;size-=1;}
     Text(g,name,size,FontStyle.Bold,new RectangleF(26,80,352,65));
     Text(g,kind==1?"请协助寻找以上人员":"请协助寻找以上物品",20,FontStyle.Regular,new RectangleF(26,151,350,32));
     Text(g,kind==1?"如有线索，请就近联系":"如拾获物品，请就近联系",20,FontStyle.Regular,new RectangleF(42,213,340,32));
     Text(g,"商场工作人员",27,FontStyle.Bold,new RectangleF(42,251,340,43));
     using(Pen pen=new Pen(Color.White,3)){
      if(kind==1){g.FillEllipse(Brushes.White,340,23,9,9);g.DrawLines(pen,new[]{new Point(344,34),new Point(344,48),new Point(338,56)});g.DrawLine(pen,344,48,350,56);g.DrawLine(pen,344,38,333,46);g.DrawLine(pen,344,38,354,46);}
      else{g.DrawEllipse(pen,333,23,20,20);g.DrawLine(pen,350,40,363,54);}
     }
    }
    for(int y=0;y<Height;y++)for(int x=0;x<Width;x++)if(bitmap.GetPixel(x,y).R>=120)p.Mask[y*BytesPerRow+x/8]|=(byte)(128>>(x%8));
   }
   p.MaskCrc=Crc(p.Mask);p.NameCrc=Crc(new UTF8Encoding(false,true).GetBytes(name));return p;
  }
  public string Header {get{return String.Format(CultureInfo.InvariantCulture,"notice {0:X4} {1:X4} {2:X4} {3}\r\n",Id,MaskCrc,NameCrc,Kind);}}
  public string Command {get{return "find "+(Kind==1?"people":"object")+" \""+Name+"\"\r\n";}}
  public string Row(int y){if(y<0||y>=Height)throw new ArgumentOutOfRangeException("y");StringBuilder b=new StringBuilder("row "+y.ToString("X4",CultureInfo.InvariantCulture)+" ");for(int i=0;i<BytesPerRow;i++)b.Append(Mask[y*BytesPerRow+i].ToString("X2",CultureInfo.InvariantCulture));return b.Append("\r\n").ToString();}
  public Bitmap Preview(){Bitmap b=new Bitmap(Width,Height);for(int y=0;y<Height;y++)for(int x=0;x<Width;x++){
   bool foreground=(Mask[y*50+x/8]&(128>>(x%8)))!=0;Color background=y<188?Color.FromArgb(22,63,61):Color.FromArgb(250,246,236);Color ink=y<60?Color.FromArgb(233,183,124):y<188?Color.FromArgb(250,246,236):Color.FromArgb(22,63,61);
   b.SetPixel(x,y,x>=22&&x<26&&y>=214&&y<284?Color.FromArgb(189,121,82):foreground?ink:background);
  }return b;}
 }
}
