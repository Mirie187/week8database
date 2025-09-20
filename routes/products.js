// routes/products.js
const express = require('express');
const router = express.Router();
const db = require('../db');

// GET /api/products  -> list all products
router.get('/', async (req, res) => {
  try {
    const [rows] = await db.query('SELECT product_id, sku, name, description, price, stock FROM products ORDER BY created_at DESC');
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// GET /api/products/:id
router.get('/:id', async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM products WHERE product_id = ?', [req.params.id]);
    if (rows.length === 0) return res.status(404).json({ error: 'Product not found' });
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// POST /api/products  -> create product
router.post('/', async (req, res) => {
  const { sku, name, description, price, stock } = req.body;
  try {
    const [result] = await db.query(
      'INSERT INTO products (sku,name,description,price,stock) VALUES (?,?,?,?,?)',
      [sku, name, description || null, price || 0, stock || 0]
    );
    const [row] = await db.query('SELECT * FROM products WHERE product_id = ?', [result.insertId]);
    res.status(201).json(row[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error or duplicate SKU' });
  }
});

// PUT /api/products/:id  -> update product
router.put('/:id', async (req, res) => {
  const { sku, name, description, price, stock } = req.body;
  try {
    await db.query(
      'UPDATE products SET sku=?, name=?, description=?, price=?, stock=? WHERE product_id=?',
      [sku, name, description || null, price || 0, stock || 0, req.params.id]
    );
    const [row] = await db.query('SELECT * FROM products WHERE product_id = ?', [req.params.id]);
    res.json(row[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

// DELETE /api/products/:id
router.delete('/:id', async (req, res) => {
  try {
    await db.query('DELETE FROM products WHERE product_id = ?', [req.params.id]);
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

module.exports = router;
