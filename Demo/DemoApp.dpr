program DemoApp;

{$R 'dlg.res' 'dlg.rc'}

uses
  Vcl.Forms,
  Demo in 'Demo.pas' {Form2},
  DlgCountdown in '..\DlgCountdown.pas';

{$R *.res}
{$R 'dlg.res' 'dlg.rc'}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm2, Form2);
  Application.Run;
end.
