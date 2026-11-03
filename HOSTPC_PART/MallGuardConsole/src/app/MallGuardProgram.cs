// MallGuard 商场多媒体与应急显示终端 · Windows控制台
// 职责：应用入口、离线/自动验证参数；普通启动不自动发送应急命令。
// 保留V5.1类/方法标识以兼容现有测试，文件名按产品职责组织。
using System;
using System.IO;
using System.Windows.Forms;
namespace MallDisplayConsole {
    static class Program {
        [STAThread] static void Main(string[] args) {
            bool demo=false,smoke=false;string captures=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"smoke-data");
            for(int i=0;i<args.Length;i++){if(args[i]=="--guided-smoke-test"){smoke=true;MainForm.GuidedSmokeEnabled=true;}else if(args[i]=="--experience-smoke-test"){smoke=true;MainForm.ExperienceSmokeEnabled=true;}else if(args[i]=="--playback-smoke-test"){smoke=true;MainForm.PlaybackSmokeEnabled=true;}else if(args[i]=="--finder-smoke-test"){smoke=true;MainForm.FinderSmokeEnabled=true;}else if(args[i]=="--demo")demo=true;else if(args[i]=="--smoke-test")smoke=true;else if(args[i]=="--capture-dir"&&i+1<args.Length)captures=Path.GetFullPath(args[++i]);}
            Application.SetUnhandledExceptionMode(UnhandledExceptionMode.ThrowException);
            try {
                Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);
                Application.Run(new MainForm(demo,smoke,captures));
            } catch(Exception e) {
                string dir=smoke?captures:Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"data");Directory.CreateDirectory(dir);File.WriteAllText(Path.Combine(dir,"startup_error.txt"),e.ToString());Environment.ExitCode=1;
                if(!smoke)MessageBox.Show(e.Message,"控制台启动失败",MessageBoxButtons.OK,MessageBoxIcon.Error);
            }
        }
    }
}
