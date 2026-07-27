const { Client } = require('ssh2');

const conn = new Client();
conn.on('ready', () => {
  console.log('Client :: ready');
  const commands = [
    'rm -rf /root/tajer-web-build',
    'git clone https://github.com/mahmoud1xxxx1-bit/tajer.git /root/tajer-web-build',
    'cd /root/tajer-web-build',
    'export PATH="$PATH:/root/flutter/bin"',
    'flutter pub get',
    'flutter build web --base-href "/admin/" --web-renderer canvaskit',
    'rm -rf /home/alldown.uk/public_html/admin/*',
    'cp -r build/web/* /home/alldown.uk/public_html/admin/',
    'echo "Deployment successful"'
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
