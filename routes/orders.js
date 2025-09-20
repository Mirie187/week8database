// routes/orders.js
const express = require('express');
const router = express.Router();
const db = require('../db');

/**
 * GET /api/orders   -> list orders (basic)
 */
router.get('/', async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT o.order_id, o.customer_id, o.status, o.total, o.created_at,
              c.first_name, c.last_name
       FROM orders o
       LEFT JOIN customers c ON o.customer_id = c.customer_id
       ORDER BY o.created_at DESC LIMIT 50`
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

/**
 * GET /api/orders/:id   -> order details + items
 */
router.get('/:id', async (req, res) => {
  try {
    const [[order]] = await db.query(
      `SELECT o.*, c.first_name, c.last_name, a.street, a.city
       FROM orders o
       LEFT JOIN customers c ON o.customer_id = c.customer_id
       LEFT JOIN addresses a ON o.address_id = a.address_id
       WHERE o.order_id = ?`, [req.params.id]
    );
    if (!order) return res.status(404).json({ error: 'Order not found' });

    const [items] = await db.query(
      `SELECT oi.order_item_id, oi.product_id, p.name, oi.quantity, oi.unit_price, oi.line_total
       FROM order_items oi
       LEFT JOIN products p ON oi.product_id = p.product_id
       WHERE oi.order_id = ?`, [req.params.id]
    );

    res.json({ order, items });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB error' });
  }
});

/**
 * POST /api/orders  -> create order with items (simple)
 * Body: { customer_id, address_id, items: [{product_id, quantity}] }
 */
router.post('/', async (req, res) => {
  const { customer_id, address_id, items } = req.body;
  if (!customer_id || !address_id || !Array.isArray(items) || items.length === 0) {
    return res.status(400).json({ error: 'customer_id, address_id and items[] are required' });
  }

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    // Insert order (total will be updated after items)
    const [orderRes] = await conn.query('INSERT INTO orders (customer_id, address_id, status, total) VALUES (?, ?, ?, ?)', [customer_id, address_id, 'pending', 0.00]);
    const orderId = orderRes.insertId;

    // Insert items; calculate line totals
    for (const it of items) {
      const [prodRows] = await conn.query('SELECT price, stock FROM products WHERE product_id = ?', [it.product_id]);
      if (prodRows.length === 0) throw new Error(`Product ${it.product_id} not found`);
      const price = parseFloat(prodRows[0].price);
      const quantity = parseInt(it.quantity, 10);
      if (quantity <= 0) throw new Error('Invalid quantity');

      await conn.query('INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES (?, ?, ?, ?)', [orderId, it.product_id, quantity, price]);

      // decrement stock (simple)
      await conn.query('UPDATE products SET stock = stock - ? WHERE product_id = ? AND stock >= ?', [quantity, it.product_id, quantity]);
    }

    // update order total
    await conn.query('UPDATE orders SET total = (SELECT COALESCE(SUM(line_total),0) FROM order_items WHERE order_id = ?) WHERE order_id = ?', [orderId, orderId]);

    await conn.commit();
    const [[orderRow]] = await conn.query('SELECT * FROM orders WHERE order_id = ?', [orderId]);
    res.status(201).json({ order: orderRow });
  } catch (err) {
    await conn.rollback();
    console.error(err);
    res.status(500).json({ error: err.message || 'DB error' });
  } finally {
    conn.release();
  }
});

module.exports = router;
