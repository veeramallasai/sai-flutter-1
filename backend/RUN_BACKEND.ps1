$ErrorActionPreference="Stop"

$ROOT=Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ROOT

$candidates=@(
    $env:JAVA_HOME,
    "C:\Program Files\Android\Android Studio\jbr",
    "C:\Program Files\Eclipse Adoptium\jdk-21.0.12.8-hotspot",
    "C:\Program Files\Eclipse Adoptium\jdk-17",
    "C:\Program Files\Java\jdk-21",
    "C:\Program Files\Java\jdk-17"
)

$JAVA=$null

foreach($j in $candidates){
    if($j -and (Test-Path "$j\bin\java.exe")){
        $JAVA=$j
        break
    }
}

if(!$JAVA){
    throw "Java not found."
}

$env:JAVA_HOME=$JAVA
$env:PATH="$JAVA\bin;$env:PATH"

Write-Host "JAVA_HOME = $JAVA" -ForegroundColor Green
java -version

if(!$env:DB_URL){
    $env:DB_URL="jdbc:postgresql://localhost:5432/farm_to_home"
}

if(!$env:DB_USERNAME){
    $env:DB_USERNAME="postgres"
}

if(!$env:DB_PASSWORD){

    $secure=Read-Host "Enter PostgreSQL password" -AsSecureString

    $ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)

    try{
        $env:DB_PASSWORD=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    }
    finally{
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

if(Test-Path ".\mvnw.cmd"){
    .\mvnw.cmd spring-boot:run
}
elseif(Test-Path "$env:LOCALAPPDATA\Programs\apache-maven-3.9.16\bin\mvn.cmd"){
    & "$env:LOCALAPPDATA\Programs\apache-maven-3.9.16\bin\mvn.cmd" spring-boot:run
}
else{
    mvn spring-boot:run
}
