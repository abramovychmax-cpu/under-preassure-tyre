$adb = "C:\Users\abram\AppData\Local\Android\Sdk\platform-tools\adb.exe"
& $adb logcat -c
Start-Sleep -Seconds 1
& $adb logcat | Select-String "ATTEMPT|Hex:|Dec:" -MaxMatches 50
