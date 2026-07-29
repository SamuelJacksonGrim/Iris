' Iris launcher - starts the app with no terminal / console window at all.
' Double-click this (or a shortcut to it) to open Iris.
Set sh = CreateObject("WScript.Shell")
sh.Run "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""C:\Users\spamw\tools\Iris\iris.ps1""", 0, False
