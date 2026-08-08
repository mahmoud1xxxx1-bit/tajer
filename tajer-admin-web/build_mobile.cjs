const { Client } = require('ssh2');
const fs = require('fs');

const conn = new Client();
const localFile = 'c:\\Users\\loved\\gamex1\\tajer-mobile.zip';
const remoteFile = '/root/tajer-mobile.zip';

conn.on('ready', () => {
  console.log('Client :: ready');
  conn.sftp((err, sftp) => {
    if (err) throw err;
    console.log('Uploading mobile app zip to VPS...');
    sftp.fastPut(localFile, remoteFile, {}, (err) => {
      if (err) throw err;
      console.log('Upload complete. Unzipping and building...');
      
      const script = `
        cd /root
        rm -rf tajer-mobile
        unzip -o tajer-mobile.zip -d tajer-mobile
        cd tajer-mobile

        # Ensure flutter is installed
        if ! command -v flutter &> /dev/null
        then
            echo "Flutter not found. Installing..."
            snap install flutter --classic
            flutter config --no-analytics
        fi
        
        # We need Android SDK
        # Actually snap install flutter installs flutter, but we need android sdk
        # Let's run flutter pub get and see if it fails (it will if no Android SDK for apk/aab build, but wait! We can just use flutter analyze first!)
        
        echo "Running flutter analyze..."
        flutter pub get
        flutter analyze > analyze_result.txt 2>&1
        cat analyze_result.txt
        echo "Done"
      `;
      
      conn.exec(script, (err, stream) => {
        if (err) throw err;
        stream.on('close', (code, signal) => {
          console.log('Build process completed with code ' + code);
          conn.end();
        }).on('data', (data) => {
          console.log('STDOUT: ' + data);
        }).stderr.on('data', (data) => {
          console.log('STDERR: ' + data);
        });
      });
    });
  });
}).connect({
  host: '163.245.218.57',
  port: 22,
  username: 'root',
  password: process.env.VPS_PASSWORD
});
