unit Demo;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  DlgCountdown;

type
  TForm2 = class(TForm)
    Button1: TButton;
    Memo1: TMemo;
    procedure Button1Click(Sender: TObject);
  private
    procedure Log(const Msg: string);
  end;

var
  Form2: TForm2;

implementation

{$R *.dfm}

{$I dlg.inc}

// оконная процедура диалога
function DialogProc(hWnd: HWND; msg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var EndDlgCmd: Boolean;
    i: Integer;
begin
  case Msg of
    // Нотифай от дочернего контрола. Проверяем, если это нажата кнопка либо Escape, то завершить диалог.
    WM_COMMAND:
      begin
        EndDlgCmd := False;
        // Нажат Escape? HIWORD(wParam) = 0, LOWORD(wParam) = IDCANCEL
        if (HIWORD(wParam) = 0) and (LOWORD(wParam) = IDCANCEL) then
          EndDlgCmd := True
        // Нажата кнопка? HIWORD(wParam) = BN_CLICKED, LOWORD(wParam) = Btn_ID
        else if HIWORD(wParam) = BN_CLICKED then
          if LOWORD(wParam) in [IDOK, IDRETRY] then // ищем ID кнопки в списке ID, завершающих диалог
            EndDlgCmd := True;
        // Диалог действительно завершается
        if EndDlgCmd then
          EndDialog(hWnd, LOWORD(wParam));
      end; // WM_COMMAND
  end; // case

  // все остальные случаи - предварительно ставим отрицательный результат и запускаем обработчик
  Result := LRESULT(False);
end;

procedure TForm2.Button1Click(Sender: TObject);

const
  ModalResults: array[1..11] of string =
    ('OK', 'Cancel', 'Abort', 'Retry', 'Ignore', 'Yes', 'No', 'Close', 'Help', 'TryAgain', 'Continue');
type
  TTestFunc = reference to procedure(var Res: NativeInt);

var
  TestCounter, FailCounter: Integer;

procedure DoTest(const TestDescr: string; Func: TTestFunc; RequiredResult: NativeInt);
var
  res: NativeInt;
begin
  Inc(TestCounter);
  Log('~ Test #'+IntToStr(TestCounter)+'. '+TestDescr);
  Log('  Dlg starting');
  Func(res);
  Log('  Dlg finished with result "'+ModalResults[res]+'"');
  if res <> RequiredResult then
  begin
    Log('!!! Test failed');
    Inc(FailCounter);
  end
  else
    Log('~ Test #'+IntToStr(TestCounter)+' passed');
end;

function CreateTestForm: TForm;
begin
  Result := TForm.Create(Self);
  Result.SetBounds(0, 0, 300, 300);
  Result.Position := poScreenCenter;
  with TButton.Create(Result) do
  begin
    Parent := Result;
    Name := 'btnOK';
    Caption := 'OK';
    ModalResult := mrYes;
    SetBounds(0, 0, 60, 30);
  end;
  with TButton.Create(Result) do
  begin
    Parent := Result;
    Name := 'btnNo';
    Caption := 'No';
    ModalResult := mrNo;
    SetBounds(70, 0, 60, 30);
  end;
end;

var
  form: TForm;
  btnwnd: HWND;
  Func: TTestFunc;
const
  Countdown = 3;
begin
  TestCounter := 0; FailCounter := 0;

  // ### MsgBox ###

  Func :=
    procedure(var Res: NativeInt)
    begin
      Res := MessageBox(Handle, 'Do something bad?', 'Mmm?', MB_YESNOCANCEL);
    end;

  LaunchCountdown(Handle, Countdown, cdsByClass, 1, 'Button');
  DoTest('MsgBox, 1st button by class', Func, mrYes);

  LaunchCountdown(Handle, Countdown, cdsByText, 0, '&Нет');
  DoTest('MsgBox, button by text',Func, mrNo);

  LaunchCountdown(Handle, Countdown, cdsByClass, 2, 'Button', 'Nein!');
  DoTest('MsgBox, change initial button text', Func, mrNo);

  // ### Form ###

  Func :=
    procedure(var Res: NativeInt)
    begin
      Res := form.ShowModal;
    end;

  form := CreateTestForm;
  LaunchCountdown(Handle, Countdown, cdsByClass, 2, 'TButton');
  DoTest('Form, 1st button by class', Func, mrYes);
  form.Free;

  form := CreateTestForm;
  LaunchCountdown(Handle, Countdown, cdsByText, 0, 'No');
  DoTest('Form, button by text', Func, mrNo);
  form.Free;

  form := CreateTestForm;
  btnwnd := (form.FindChildControl('btnOK') as TButton).Handle;
  LaunchCountdown(Handle, Countdown, cdsHwnd, btnwnd, '');
  DoTest('Form, button by handle', Func, mrYes);
  form.Free;

  // ### Dialog ###

  Func :=
    procedure(var Res: NativeInt)
    begin
      Res := DialogBoxParam(HInstance, MakeIntResource(IDD_DLGMSGBOX), Handle, @DialogProc, LPARAM(Self));
    end;

  LaunchCountdown(Handle, Countdown, cdsByClass, 1, 'Button');
  DoTest('Dialog, 2nd button by class', Func, mrRetry);

  LaunchCountdown(Handle, Countdown, cdsByDlgID, IDRETRY, '');
  DoTest('Dialog, button by dialog ID', Func, mrRetry);

  LaunchCountdown(Handle, Countdown, cdsByClass, 2, 'Button', 'Dismiss');
  DoTest('Dialog, change initial button text', Func, mrCancel);

  // ### Resume ###

  if FailCounter = 0 then
    Log(Format('@@ All %d tests passed @@', [TestCounter]))
  else
    Log(Format('@@ %d/%d test(s) failed', [FailCounter, TestCounter]));
end;

procedure TForm2.Log(const Msg: string);
begin
  Memo1.Lines.Add(Msg);
end;

end.
