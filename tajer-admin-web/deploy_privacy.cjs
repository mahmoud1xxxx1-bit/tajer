const { Client } = require('ssh2');
const fs = require('fs');

const conn = new Client();
const localFile = 'c:\\Users\\loved\\gamex1\\tajer\\privacy.html';
const remoteFile = '/home/alldown.uk/public_html/privacy.html';

conn.on('ready', () => {
  console.log('Client :: ready');
  conn.sftp((err, sftp) => {
    if (err) throw err;
    console.log('Uploading privacy.html...');
    sftp.fastPut(localFile, remoteFile, {}, (err) => {
      if (err) throw err;
      console.log('Upload complete.');
      conn.end();
    });
  });
}).connect({
  host: '163.245.218.57',
  port: 22,
  username: 'root',
  password: process.env.VPS_PASSWORD
});
