const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');
const bodyParser = require('body-parser');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const i18n = require('i18n');
const { OpenAI } = require('openai');
const multer = require('multer');
const path = require('path');
const stripe = require('stripe')('sua_chave_secreta_stripe');
const app = express();
const port = 3000;
const secretKey = 'your_secret_key';

// Configuração do upload de imagens
const storage = multer.diskStorage({
  destination: './uploads/logos/',
  filename: (req, file, cb) => {
    cb(null, file.fieldname + '-' + Date.now() + path.extname(file.originalname));
  }
});
const upload = multer({ storage: storage });

// Configuração do Chatbot
const openai = new OpenAI({ apiKey: 'sua_chave_openai' });

// Configuração de multi-idiomas
i18n.configure({
  locales: ['en', 'es', 'pt'],
  directory: __dirname + '/locales',
  defaultLocale: 'en',
  cookie: 'lang'
});

app.use(i18n.init);
app.use(cors());
app.use(bodyParser.json());
app.use('/uploads', express.static('uploads'));

// Database connection
const db = mysql.createConnection({
  host: 'localhost',
  user: 'root',
  password: '',
  database: 'iptv_panel'
});

db.connect(err => {
  if (err) {
    console.error('Erro ao conectar ao banco de dados:', err);
    return;
  }
  console.log('Conectado ao banco de dados MySQL');
});

// Middleware de autenticação
const authenticate = (req, res, next) => {
  const token = req.headers['authorization'];
  if (!token) return res.status(403).json({ error: res.__('Token não fornecido') });
  jwt.verify(token, secretKey, (err, decoded) => {
    if (err) return res.status(401).json({ error: res.__('Token inválido') });
    req.user = decoded;
    next();
  });
};

// Criar Canal
app.post('/channels', authenticate, (req, res) => {
  const { name, url, category, logo } = req.body;
  db.query('INSERT INTO channels (name, url, category, logo) VALUES (?, ?, ?, ?)', [name, url, category, logo], (err, result) => {
    if (err) return res.status(500).json({ error: res.__('Erro ao criar canal') });
    res.json({ message: res.__('Canal criado com sucesso') });
  });
});

// Listar Canais
app.get('/channels', authenticate, (req, res) => {
  db.query('SELECT * FROM channels', (err, results) => {
    if (err) return res.status(500).json({ error: res.__('Erro ao buscar canais') });
    res.json(results);
  });
});

// Criar Filme ou Série
app.post('/media', authenticate, (req, res) => {
  const { title, type, url, category, poster } = req.body;
  db.query('INSERT INTO media (title, type, url, category, poster) VALUES (?, ?, ?, ?, ?)', [title, type, url, category, poster], (err, result) => {
    if (err) return res.status(500).json({ error: res.__('Erro ao adicionar mídia') });
    res.json({ message: res.__('Mídia adicionada com sucesso') });
  });
});

// Listar Filmes e Séries
app.get('/media', authenticate, (req, res) => {
  db.query('SELECT * FROM media', (err, results) => {
    if (err) return res.status(500).json({ error: res.__('Erro ao buscar mídias') });
    res.json(results);
  });
});

// Adicionar EPG
app.post('/epg', authenticate, (req, res) => {
  const { channel_id, program, start_time, end_time } = req.body;
  db.query('INSERT INTO epg (channel_id, program, start_time, end_time) VALUES (?, ?, ?, ?)', [channel_id, program, start_time, end_time], (err, result) => {
    if (err) return res.status(500).json({ error: res.__('Erro ao adicionar EPG') });
    res.json({ message: res.__('EPG adicionado com sucesso') });
  });
});

// Listar EPG
app.get('/epg', authenticate, (req, res) => {
  db.query('SELECT * FROM epg', (err, results) => {
    if (err) return res.status(500).json({ error: res.__('Erro ao buscar EPG') });
    res.json(results);
  });
});

// Player para monitorar canais
app.get('/channels/:id/play', authenticate, (req, res) => {
  const { id } = req.params;
  db.query('SELECT url FROM channels WHERE id = ?', [id], (err, results) => {
    if (err || results.length === 0) return res.status(404).json({ error: res.__('Canal não encontrado') });
    const streamUrl = results[0].url;
    res.json({ player: `<video controls autoplay><source src='${streamUrl}' type='application/x-mpegURL'></video>` });
  });
});

// Rotas de teste
app.get('/', (req, res) => {
  res.send(res.__('Painel de IPTV está rodando!'));
});

// Iniciar servidor
app.listen(port, () => {
  console.log(`Servidor rodando na porta ${port}`);
});
