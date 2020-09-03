# Stop all containers
docker stop $(docker ps -a -q)

# Remove all containers
docker rm $(docker ps -a -q)

# Remove all images
docker rmi -f $(docker images -a -q)

# Start Chrome with no CORS check
"Program Files (x86)\Google\Chrome\Application\chrome.exe" --disable-web-security --user-data-dir="C:\Users\Money\Downloads\chrome"