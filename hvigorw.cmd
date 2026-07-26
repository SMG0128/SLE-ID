@REM hvigor build script for HarmonyOS (Windows)

@REM Determine the project root directory
@setlocal
@set PRG=%~f0

@REM Find java
@if defined JAVA_HOME (
    @set JAVACMD=%JAVA_HOME%\bin\java.exe
) else (
    @set JAVACMD=java.exe
)

@REM Execute hvigor
@"%JAVACMD%" -jar "%~dp0hvigor\hvigor-ohos.jar" %*
