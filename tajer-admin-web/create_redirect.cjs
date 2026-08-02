const { Client } = require('ssh2');
const conn = new Client();

const html = `<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta http-equiv="refresh" content="0; url=https://alldown.uk/taj/login" />
    <script>window.location.href = "https://alldown.uk/taj/login";</script>
</head>
<body>
    Redirecting...
</body>
</html>`;

const escapedHtml = html.replace(/'/g, "'\\''");
const cmd = `echo '${escapedHtml}' > /home/alldown.uk/public_html/index.html && chown nobody:nobody /home/alldown.uk/public_html/index.html`;

conn.on('ready', () => {
  console.log('Client :: ready');
  conn.exec(cmd, (err, stream) => {
    if (err) throw err;
    stream.on('close', (code, signal) => {
      console.log('Done');
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
