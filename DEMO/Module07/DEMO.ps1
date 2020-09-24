# azcopy login

azcopy make 'https://lab07bol.blob.core.windows.net/azcopy?sv=2019-12-12&ss=bfqt&srt=sco&sp=rwdlacupx&se=2020-09-24T01:40:09Z&st=2020-09-23T17:40:09Z&spr=https&sig=%2BX%2BB43glOeQKLUSvKTDG8bNl6xyQ%2FmwWtxcvnbCU4HY%3D'

# Upload the file
azcopy copy 'C:\Users\tzyu\Downloads\Azure.png' 'https://lab07bol.blob.core.windows.net/azcopy/Azure.png?sv=2019-12-12&ss=bfqt&srt=sco&sp=rwdlacupx&se=2020-09-24T01:40:09Z&st=2020-09-23T17:40:09Z&spr=https&sig=%2BX%2BB43glOeQKLUSvKTDG8bNl6xyQ%2FmwWtxcvnbCU4HY%3D'

# Download the file
azcopy copy 'https://lab07bol.blob.core.windows.net/azcopy/Azure.png?sv=2019-12-12&ss=bfqt&srt=sco&sp=rwdlacupx&se=2020-09-24T01:40:09Z&st=2020-09-23T17:40:09Z&spr=https&sig=%2BX%2BB43glOeQKLUSvKTDG8bNl6xyQ%2FmwWtxcvnbCU4HY%3D' 'C:\Users\tzyu\Downloads\DemoDownloadAzure.png'