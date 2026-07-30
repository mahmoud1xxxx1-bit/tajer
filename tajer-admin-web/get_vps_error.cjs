const { Client } = require('ssh2');

const conn = new Client();
conn.on('ready', () => {
  console.log('Client :: ready');
  const commands = [
    'cd /root/tajer-web-build',
    'git fetch origin main',
    'git reset --hard origin/main',
    'export PATH="$PATH:/root/flutter/bin"',
    'flutter pub get',
    'flutter analyze'
  ];
  conn.exec(commands.join(' && '), (err, stream) => {
    if (err) throw err;
    stream.on('close', (code, signal) => {
      console.log('Stream :: close :: code: ' + code + ', signal: ' + signal);
      conn.end();
    }).on('data', (data) => {
      console.log('STDOUT: ' + data);
    }).stderr.on('data', (data) => {
      console.log('STDERR: ' + data);
    });
  });
}).connect({
  host: '163.245.218.57',
  port: 22,
  username: 'root',
  password: '0598106535Mm@'
});
