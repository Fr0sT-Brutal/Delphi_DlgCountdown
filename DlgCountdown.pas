// *************** ДОБАВЛЕНИЕ ТАЙМЕРА НА КНОПКИ ДИАЛОГОВ *************** \\

unit DlgCountdown;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes;

type
  // Как искать кнопку:
  //   cdsByClass - по классу и индексу.
  //     BtnID - индекс, BtnStr - класс.
  //     Выполняется перебор дочерних окон в Z-порядке и берётся BtnID-ое (начиная с 1) окно с классом BtnStr.
  //     Для VCL окон это название класса объекта ('TButton' etc), для WinApi -
  //     название класса *окна* (обычно 'Button').
  //     !! Перебор выполняется по Z-order, а не в порядке табуляции или создания !!
  //   cdsByDlgID - по dialog ID (только для диалогов, загруженных из ресурсов).
  //     BtnID - dialog ID, BtnStr - не используется.
  //   cdsByText - по тексту (WindowText). Возвращается первое найденное окно с таким текстом
  //     BtnID - не используется, BtnStr - текст окна
  //   cdsHwnd - по хэндлу (для предварительно созданных диалогов, форм)
  //     BtnID - хэндл, BtnStr - не используется.
  TCountdownDlgSearchType = (cdsByClass, cdsByDlgID, cdsByText, cdsHwnd);

// Запустить тред, который добавит обратный отсчет на вызванный диалог.
//    ParentWnd - хэндл окна, вызывающего диалог (служит для определения момента
//      появления диалога; диалогом будет считаться модальное окно, которое будет
//      иметь ParentWnd как owner
//    Secs - величина обратного отсчета
//    SearchType - тип поиска контрола
//    BtnID - см. TCountdownDlgSearchType
//    BtnStr - см. TCountdownDlgSearchType
//    BtnCaption [opt] - Базовая часть надписи, которая будет присвоена кнопке
//      Имеет смысл, если изначально на кнопке нет надписи вообще
procedure LaunchCountdown(ParentWnd: HWND; Secs: Integer;
                          SearchType: TCountdownDlgSearchType;
                          BtnID: NativeInt;
                          const BtnStr: string;
                          const BtnCaption: string = '');

implementation

// Имитирует нажатие на кнопку.
procedure PushButton(ParentWnd, ButtonWnd: HWND);
begin
  // Если окно не диалог - GetDlgCtrlID вернет ButtonWnd, так что обрезаем его до Word;
  //  в этом случае значение и не будет использоваться
  SendMessage(ParentWnd, WM_COMMAND, MakeWParam(Word(GetDlgCtrlID(ButtonWnd)), BN_CLICKED), ButtonWnd);
end;

// Поиск кнопки по указанным опциям
//    ParentWnd - родительское окно
//    SearchType - тип поиска контрола
//    BtnID - см. TCountdownDlgSearchType
//    BtnStr - см. TCountdownDlgSearchType
function FindButton(ParentWnd: HWND;
                    SearchType: TCountdownDlgSearchType;
                    BtnID: NativeInt;
                    const BtnStr: string): HWND;
var
  Counter: Integer;
begin
  case SearchType of
    // BtnID = item index
    // BtnStr = item window class
    cdsByClass:
      begin
        Result := FindWindowEx(ParentWnd, 0, PChar(BtnStr), nil);
        Counter := 0;
        while Result <> 0 do
        begin
          Inc(Counter);
          if Counter = BtnID then
            Break;
          Result := FindWindowEx(ParentWnd, Result, PChar(BtnStr), nil);
        end;
      end;
    // BtnID = Dlg item ID
    cdsByDlgID:
      Result := GetDlgItem(ParentWnd, BtnID);
    // BtnStr = button text
    cdsByText:
      Result := FindWindowEx(ParentWnd, 0, nil, PChar(BtnStr));
    // BtnID = button HWND
    cdsHwnd:
      Result := BtnID;
  end;
end;

type
  TEnumThreadWndData = record
    OwnerWnd: HWND;
    ModalWnd: HWND;
  end;
  PEnumThreadWndData = ^TEnumThreadWndData;

// Коллбэк для EnumThreadWindows
// Отбирает enabled окна, у которых owner disabled и совпадает с переданным в lParam
// Если окно найдено, возвращает его в lParam
function EnumThreadWndProc(Wnd: HWND; lPar: LPARAM): BOOL; stdcall;
var
  Owner: HWND;
begin
  if IsWindowEnabled(Wnd) then
  begin
    Owner := GetWindow(Wnd, GW_OWNER);
    if ( (lPar <> 0) and (Owner = PEnumThreadWndData(lPar).OwnerWnd) ) or
       ( (Owner <> 0) and not IsWindowEnabled(Owner) ) then
    begin
      PEnumThreadWndData(lPar).ModalWnd := Wnd;
      Exit(BOOL(0)); // Прервать перебор
    end;
  end;
  Result := BOOL(1); // Продолжить перебор
end;

function GetModalWindow(OwnerWnd: HWND; ThreadID: DWORD): HWND;
var
  etwdata: TEnumThreadWndData;
begin
  etwdata.OwnerWnd := OwnerWnd;
  etwdata.ModalWnd := 0;
  EnumThreadWindows(ThreadID, @EnumThreadWndProc, LPARAM(@etwdata));
  Result := etwdata.ModalWnd;
end;

// Запустить тред, который добавит обратный отсчет на вызванный диалог.
//    ParentWnd - хэндл окна, вызывающего диалог (служит для определения момента
//      появления диалога; диалогом будет считаться модальное окно, которое будет
//      иметь ParentWnd как owner, и при этом ParentWnd будет disabled)
//    Secs - величина обратного отсчета
//    SearchType - тип поиска контрола
//    BtnID - см. TCountdownDlgSearchType
//    BtnStr - см. TCountdownDlgSearchType
//    BtnCaption [opt] - Базовая часть надписи, которая будет присвоена кнопке
//      Имеет смысл, если изначально на кнопке нет надписи вообще
procedure LaunchCountdown(ParentWnd: HWND; Secs: Integer;
                          SearchType: TCountdownDlgSearchType;
                          BtnID: NativeInt;
                          const BtnStr: string;
                          const BtnCaption: string);
var
  CurrThreadID: DWORD;
begin
  CurrThreadID := GetCurrentThreadId;

  TThread.CreateAnonymousThread(
    procedure
    var
      Counter: Integer;
      DlgWnd, BtnWnd: HWND;
      Buf: array of Char;
      BtnLabelFmt: string;
      Len: Integer;
      CurrProcID, WndProcID: DWORD;
    const
      CounterFmt = '(%d)';
    begin
      // Ждем, пока диалог не появится. Диалогом считаем любое окно, отличное от
      // ParentWnd, которое появится в данном треде поверх остальных.
      repeat
        DlgWnd := GetModalWindow(ParentWnd, CurrThreadID);
        if (DlgWnd <> 0) and (DlgWnd <> ParentWnd) then
          Break;
        Sleep(100);
      until False;

      // Находим нужную кнопку
      BtnWnd := FindButton(DlgWnd, SearchType, BtnID, BtnStr);
      if not IsWindow(BtnWnd) then
        Exit;

      // Определяем надпись на кнопке: из параметра, из имеющегося или просто отсчет, если оба пусты
      BtnLabelFmt := ''; Len := 0;
      if BtnCaption <> '' then
        BtnLabelFmt := BtnCaption + ' ' + CounterFmt
      else
      begin
        Len := GetWindowTextLength(BtnWnd);
        if Len > 0 then
        begin
          SetLength(Buf, Len + 1); // + завершающий нулевой
          if GetWindowText(BtnWnd, PChar(Buf), Length(Buf)) > 0 then
            BtnLabelFmt := StrPas(PChar(Buf)) + ' ' + CounterFmt;
        end;
      end;
      if BtnLabelFmt = '' then
        BtnLabelFmt := CounterFmt; // текста нет или ошибка получения

      Counter := Secs;

      SetWindowText(BtnWnd, Format(BtnLabelFmt, [Counter]));
      while Counter > 0 do
      begin
        // Уменьшить счётчик
        Sleep(1*MSecsPerSec);
        Dec(Counter);
        // Если диалог уже закрыли
        if not IsWindow(DlgWnd) then
          Exit;
        SetWindowText(BtnWnd, Format(BtnLabelFmt, [Counter]));
      end;
      // Счетчик дошел до конца - вернуть надпись (на всякий случай) и нажать кнопку
      if Len > 0
        then SetWindowText(BtnWnd, PChar(Buf))
        else SetWindowText(BtnWnd, nil);
      PushButton(DlgWnd, BtnWnd);
    end
  ).Start;
end;

end.
