// index.js
const express = require('express');
const bodyParser = require('body-parser');
require('dotenv').config();

const productsRouter = require('./routes/products');
const ordersRouter = require('./routes/orders');

const app = express();
app.use(bodyParser.json());

app.get('/', (req, res) => res.json({ status: 'EssenceLuxe API', version: '1.0' }));

app.use('/api/products', productsRouter);
app.use('/api/orders', ordersRouter);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server listening on port ${PORT}`));
