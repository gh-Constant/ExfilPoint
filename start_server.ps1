# Start the server in headless mode with server flag and port 7777
Start-Process -FilePath ".\ServerBuild.exe" -ArgumentList "-batchmode", "-nographics", "-server", "-port 7777", "-logfile server.log" 