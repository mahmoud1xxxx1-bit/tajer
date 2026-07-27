const { Client } = require('ssh2');
const fs = require('fs');
const path = require('path');

const conn = new Client();
const localFile = 'c:\\Users\\loved\\gamex1\\tajer-admin-web.zip';
const remoteFile = '/home/alldown.uk/public_html/tajer-admin.zip';

conn.on('ready', () => {
  console.log('Client :: ready');
  conn.sftp((err, sftp) => {
    if (err) throw err;
    console.log('Uploading zip file to VPS...');
    sftp.fastPut(localFile, remoteFile, {}, (err) => {
      if (err) throw err;
      console.log('Upload complete. Unzipping and building...');
      
      const script = `
        cd /home/alldown.uk/public_html
        rm -rf tajer-admin-src
        unzip -o tajer-admin.zip -d tajer-admin-src
        cd tajer-admin-src/tajer-admin-web
        npm install
        npm run build
        rm -rf ../../admin
        cp -r dist ../../admin
        echo "Done building admin panel"
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
  password: '0598106535Mm@'
});
