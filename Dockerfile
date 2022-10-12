# On the choice of baseimage:
# - We pick a Windows base image with the .NET SDK to allow remote translation of .NET code in SCA
# - The Windows Server Core 2019 amd64 version allows succesful installation of SCA and runs on a Windows 10 host
FROM mcr.microsoft.com/dotnet/sdk:5.0-windowsservercore-ltsc2019

# Fix SCA version
ARG SCA_VERSION=22.1.1
ENV SCA_INSTDIR=C:\\Fortify\\Fortify_SCA_and_Apps_${SCA_VERSION}
ENV SCA_INSTALLER=Fortify_SCA_and_Apps_${SCA_VERSION}_windows_x64.exe

# Copy license and software
COPY fortify.license .
COPY ${SCA_INSTALLER} .

# This prevents some warnings about missing charset cp0 when running SCA in the container
ENV JAVA_TOOL_OPTIONS="-Dsun.stderr.encoding=UTF8 -Dsun.stdout.encoding=UTF8"

# Limit heap memory. Auto heap detection doesn't work properly in Windows containers, so we need something like this.
# Specifying it on the command line isn't good enough during msbuild translation, because in that case sourceanalyzer will
# spawn another sourceanalyzer, which won't have the same memory restriction on the command line.
ENV _JAVA_OPTIONS="-Xmx1G"

# Install SCA
RUN echo fortify_license_path=fortify.license > installerSettings  && \
    echo installdir=%SCA_INSTDIR% >> installerSettings  && \
    %SCA_INSTALLER% --mode unattended --optionfile installerSettings && \
    %SCA_INSTDIR%\bin\fortifyupdate.cmd && \
    erase %SCA_INSTALLER% fortify.license installerSettings

# Install VS Build Tools; these are not part of the .NET image
# Taken from https://github.com/microsoft/dotnet-framework-docker/blob/8b4fb62b44167d78d05523abc6beb294e5b54485/src/sdk/4.8/windowsservercore-ltsc2016/Dockerfile#L35-L48
RUN powershell -Command \
        $ProgressPreference = 'SilentlyContinue'; \
        Invoke-WebRequest \
            -UseBasicParsing \
            -Uri https://download.visualstudio.microsoft.com/download/pr/45dfa82b-c1f8-4c27-a5a0-1fa7a864ae21/b5795c5efd2e27d3dccab0e27661079a2179262bbd3ad15832c4a169fb317eb1/vs_BuildTools.exe \
            -OutFile vs_BuildTools.exe \
    && start /w vs_BuildTools ^ \
        --add Microsoft.VisualStudio.Workload.MSBuildTools ^ \
        --add Microsoft.VisualStudio.Workload.NetCoreBuildTools ^ \
        --add Microsoft.Component.ClickOnce.MSBuild ^ \
        --add Microsoft.VisualStudio.Component.WebDeploy ^ \
        --quiet --norestart --nocache --wait \
    && powershell -Command "if ($err = dir $Env:TEMP -Filter dd_setup_*_errors.log | where Length -gt 0 | Get-Content) { throw $err }" \
    && del vs_BuildTools.exe

# Create a Fortify user
RUN NET USER fortify /add
RUN	NET LOCALGROUP Administrators /add fortify
USER fortify

# Put vsdevcmd.bat on the path
RUN setx path "%path%;C:\\Program Files (x86)\\Microsoft Visual Studio\\2019\\BuildTools\\Common7\\Tools"
# And run it if we enter the container without explicit command
ENTRYPOINT ["cmd.exe", "/k", "vsdevcmd.bat" ]

# Optional: copy a sample project for easier testing. This is a .NET Core 3.1 sample.
#
# With the sample project, the following end-to-end test should work:
# 1) Create container image and start container:
#     docker build . -t winfortify   (or: build.bat)
#     docker run --rm -it --name winfortify winfortify     (or: run.bat)
# 2) In container:
#     cd projects\example
#     dotnet restore
#     msbuild /t:Rebuild
#     sourceanalyzer -b example msbuild /t:Rebuild
#     sourceanalyzer -b example -scan
COPY example .\\projects\\example
