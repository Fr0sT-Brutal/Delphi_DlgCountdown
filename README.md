DlgCountdown
============

Небольшой модуль, добавляющий в любой модальный диалог функцию автовыбора одного из действий по таймеру.

Демо/тесты прилагаются.

Описание — в комментариях

Совместимость: Delphi 2009+, Windows

Простейший пример
-----------------

```delphi
LaunchCountdown(Handle, Countdown, cdsByClass, 1, 'Button');
Res := MessageBox(Handle, 'Do something bad?', 'Mmm?', MB_YESNOCANCEL);
```
