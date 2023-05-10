::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Totally Ace Health Check Report
:: written by Paul Guerin
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: test
:: set ORACLE_SID=ORCL& net start oracleservice%ORACLE_SID%& sqlplus / as sysdba
:: set ORACLE_SID=ORCL16& net start oracleservice%ORACLE_SID%& sqlplus / as sysdba
:: set ORACLE_SID=SAMPLE& net start oracleservice%ORACLE_SID%& sqlplus / as sysdba
:: set ORACLE_SID=TEST8& net start oracleservice%ORACLE_SID%& sqlplus / as sysdba

REM ~~~ setup Windows scheduled tasks to run report ~~~
REM Note: Keep task names limited to 40 characters
:: schtasks /create ^
:: /ru system ^
:: /sc minute ^
:: /MO 60 ^
:: /tn "Run cx.health.check" ^
:: /tr "cmd /C d:\cx.health.check" ^
:: /f

REM Note: alternative schedule
:: schtasks /create ^
:: /ru system ^
:: /sc daily ^
:: /tn "Run cx.health.checkt" ^
:: /tr "cmd /C d:\cx.health.check" ^
:: /st 18:00 ^
:: /f

@CLS

@SETLOCAL

:: make the script directory the working directory
@CD /d %~dp0

:: Define the input files
::@SET input.csv=%~n0.csv
@SET input.csv=cx.oracle.csv
@SET input.sql=%~n0.sql

:: Define the log file
@SET output.log=%~n0.log

:: Check if the input files exist
@IF NOT EXIST %input.csv% (
:: (
 ECHO Error: %~dp0%input.csv% doesn't exist
 ECHO.
 ECHO [ script=%~f0 ]
 ECHO.
 DIR %~dp0%input.csv%*
:: ) | msg * /w /time:15 /v
 GOTO :EOF
)
@IF NOT EXIST %input.sql% (
:: (
 ECHO Error: %~dp0%input.sql% doesn't exist
 ECHO.
 ECHO [ script=%~f0 ]
 ECHO.
 DIR %~dp0%input.sql%*
:: ) | msg * /w /time:15 /v
 GOTO :EOF
)


:: Calc minutes since midnight to make the report name unique
@SET /A time0=%time:~0,2%*60+%time:~3,2%

:: determine a timestamp (Note: must be administrator)
::@FOR /F "usebackq tokens=2 delims==." %%i IN (
::`WMIC OS Get LocalDateTime /value ^| FINDSTR [a-z0-9]`
::) ^
::DO @set datetime=%%i
::
::BS Jumpbox %date% ~ 12-Jul-13
::BS Jumpbox %time% ~ 15:14:45.78
::my laptop %date% ~ Sun 21/07/2013
::my laptop %time% ~ 19:06:29.60
::@set datetime=%date:~10,4%%date:~7,2%%date:~4,2%%time:~3,2%%time:~6,2%
::@set date0=%date:~-10%
::@set date0=%date0:/=%
::@set date0=%date0:-=%
::@set datetime=%date0%.%time0%

FOR /F "tokens=1,2,3" %%i IN ('
reg query "HKU\.Default\Control Panel\International" /v sShortDate ^| findstr "sShortDate"
') DO (
IF "%%k"=="d/MM/yyyy" (
set datetime=%date:~-4%%date:~-7,2%%date:~-10,2%.%time0%
) ELSE (
set datetime=20%date:~-2%%date:~-6,3%%date:~-9,2%.%time0%
)
)


:: make the html output file name the same as this .bat file
@SET output=%~n0.%datetime%.html

::Setup the databases as local environment variables
@FOR /F "usebackq tokens=1-7 eol=# delims==," %%i IN (`type %input.csv%`) ^
DO @set cxhc,%%i,%%j,%%k,%%l,%%m,%%n=%%o

@FOR /F "usebackq tokens=2-8 delims==," %%i IN (`set cxhc`) ^
DO @echo criticality=%%i host=%%j %%k=%%l port=%%m account/password=%%n description=%%o

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Formating and headings
:: Note: when adding another health check, also add another heading
::
:: type="disc"
:: type="circle"
:: type="square"
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
@(
ECHO ^<head^>
ECHO ^<style^>
ECHO TABLE { font: normal 9pt, calibri; border-color: silver; border-style: solid; border-width: 1px; text-align: center }
ECHO .rowI { background-color: #B0E0E6 }
ECHO .rowII { background-color: #CCFFFF }
ECHO .rowIII { background-color: #FFCCCC }
ECHO .rowWhite { background-color: #FFFFFF }
ECHO .rowBlack { background-color: #000000 }
ECHO .verticaltext {font: normal 9pt Arial; writing-mode: tb-rl;}
ECHO p { font-weight: italic }
ECHO ^</style^>
ECHO ^</head^>
ECHO ^<!-- version bat1.0 --^>
ECHO ^<body^>
ECHO ^<h1^>Health check^</h1^>
::
ECHO ^<p^>
ECHO ^<menu^>
ECHO ^<li type="disc"^>Largest utilisation: Indicates which tablespaces are about to run out of space.^</li^>
ECHO ^<li type="disc"^>Archivelogs: Indicate how much is generated in recent days.^</li^>
ECHO ^<li type="disc"^>Long running blocks/operations: Indicate potential poor performance.^</li^>
ECHO ^<li type="disc"^>Undo reuse: unexpired extent reuse^</li^>
ECHO ^<li type="disc"^>Undo consumed: consumed space^</li^>
ECHO ^</menu^>
ECHO ^</p^>
::
ECHO ^<table summary="table summary %DATE% %TIME%"^>
ECHO ^<caption^>Health check report for %DATE% %TIME%^</caption^>
ECHO ^<tr^>
::
ECHO ^<th align="left" class="verticaltext"^>Host [SID or SERVICE_NAME]^</th^>
ECHO ^<th align="left" class="verticaltext"^>Application [version]^</th^>
ECHO ^<th align="left" class="verticaltext"^>Processes %% of limit^</th^>
ECHO ^<th align="left" class="verticaltext"^>Sessions %% of limit^</th^>
ECHO ^<th align="left" class="verticaltext"^>Top 5 user sessions^</th^>
ECHO ^<th align="left" class="verticaltext"^>Top non-Undo tablespace capacity^</th^>
ECHO ^<th align="left" class="verticaltext"^>Undo reuse, Undo consumed^</th^>
ECHO ^<th align="left" class="verticaltext"^>Archivelogs^</th^>
ECHO ^<th align="left" class="verticaltext"^>Blocks^</th^>
ECHO ^<th align="left" class="verticaltext"^>LongOps^</th^>
ECHO ^<th align="left" class="verticaltext"^>ASM^</th^>
ECHO ^<th align="left" class="verticaltext"^>Files that require media recovery^</th^>
::
ECHO ^</tr^>
) > %output%

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Health checks
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
@ECHO.
@ECHO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
@ECHO Note1: Some logins may be extremely slow
@ECHO.
@ECHO Note2: Other logins will require the enter key to progress past ORA-28011
@ECHO        ORA-28011: the account will expire soon; change your password now
@ECHO.
@ECHO Note3: Clicking in the session window forces the execution to halt.
@ECHO        Press the 'escape' key to resume execution
@ECHO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
@ECHO.
@ECHO Monitor execution by opening and refreshing: %~dp0%output%
@ECHO.
:: PowderBlue
@set colour=#B0E0E6
@FOR /F "usebackq tokens=2-8 delims==," %%i IN (`set cxhc ^| FINDSTR [a-z0-9]`) ^
DO @(
set /A databasecount += 1
ECHO ##################################################################################################
ECHO %%n@(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP^)(Host=%%j^)(Port=%%m^)^)^)(CONNECT_DATA=(%%k=%%l^)^)^)
ECHO ##################################################################################################
) & @(
ECHO ^</tr^>
ECHO ^<tr class="rowI"^>
ECHO ^<td BGCOLOR="%colour%"^>
ECHO %%j^<br^>
ECHO ^<a id="
ECHO #(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP^)(Host=%%j^)(Port=%%m^)^)^)(CONNECT_DATA=(%%k=%%l^)^)^)"^>
ECHO [%%k=%%l]^</a^>^<br^>
date /t & time /t
ECHO ^</td^>
ECHO ^<td BGCOLOR="%colour%"^>^<a title="app+version"^>%%o^<br^>
) >> %output% & ^
sqlplus -S -L ^
%%n@(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)^
(Host=%%j)(Port=%%m)))(CONNECT_DATA=(%%k=%%l))) ^
@%input.sql% %colour% %output%

::
:: | find /V "Session altered." & ECHO ^</tr^>
:: PROMPT <!--
:: select to_char(sysdate,'ddMonyyy hh:mm:ss') from dual;
:: PROMPT -->
::

:: Insert a placeholder for any Oracle 7 databases
@(
ECHO ^</tr^>^<tr class="rowI"^>
ECHO ^<td BGCOLOR="%colour%"^>grover^<br^>[SID=TDOC]^</td^>
ECHO ^<td BGCOLOR="%colour%"^>Technical Document Management System^<br^>[7.3.4.0.1]^</td^>
ECHO ^</tr^>
) >> %output%

@ECHO.
:: Determine report elapsed time
@SET /A elapsed=%time:~0,2%*60+%time:~3,2%-%time0%
@ECHO elapsed time = %elapsed% minutes

@(
ECHO ^</table^>
ECHO ^<footer^>elapsed time = %elapsed% minutes^<br^>
ECHO Number of databases processed=%databasecount%^<br^>
ECHO USERNAME=%USERNAME%^<br^>
net user %USERNAME% /domain | find "Full Name"
ECHO ^</footer^>
ECHO ^</body^>
) >> %output%

@ECHO ###################################################################################################


@ECHO.
@ECHO Number of databases processed=%databasecount%

@ECHO.
@ECHO To open output file in excel.......
@ECHO "C:\Program Files (x86)\Microsoft Office\Office12\excel" /e "%~dp0%output%"

@ECHO.
@ECHO Opening output file in web browser.......
%~dp0%output%

@ECHO.
@ECHO ##### script end #####

@ENDLOCAL

EXIT




ECHO %%j^<br^>[%%k=%%l]^<br^>
