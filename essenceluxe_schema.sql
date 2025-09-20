-- ============================================
-- essenceluxe_schema.sql
-- Database schema for Essence Luxe (E-commerce)
-- Creates database, tables, constraints and sample data
-- ============================================

DROP DATABASE
IF
  EXISTS essenceluxe;
  CREATE DATABASE essenceluxe CHARACTER
  SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  USE essenceluxe;

  -- Customers
  CREATE TABLE customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY
    , first_name VARCHAR(100) NOT NULL
    , last_name VARCHAR(100) NOT NULL
    , email VARCHAR(255) NOT NULL UNIQUE
    , phone VARCHAR(30)
    , created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );

  -- Addresses (one customer can have many addresses)
  CREATE TABLE addresses (
    address_id INT AUTO_INCREMENT PRIMARY KEY
    , customer_id INT NOT NULL
    , street VARCHAR(255) NOT NULL
    , city VARCHAR(100) NOT NULL
    , state VARCHAR(100)
    , postal_code VARCHAR(20)
    , country VARCHAR(100) NOT NULL
    , is_default BOOLEAN DEFAULT FALSE
    , FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
    ON DELETE CASCADE
  );

  -- Products
  CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY
    , sku VARCHAR(50) NOT NULL UNIQUE
    , name VARCHAR(200) NOT NULL
    , description TEXT
    , price DECIMAL(10, 2) NOT NULL CHECK (price >= 0)
    , stock INT NOT NULL DEFAULT 0
    , created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );

  -- Categories (product lines)
  CREATE TABLE categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY
    , name VARCHAR(100) NOT NULL UNIQUE
    , description VARCHAR(255)
  );

  -- Many-to-many: product_categories
  CREATE TABLE product_categories (
    product_id INT NOT NULL
    , category_id INT NOT NULL
    , PRIMARY KEY (product_id, category_id)
    , FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON DELETE CASCADE
    , FOREIGN KEY (category_id) REFERENCES categories(category_id)
    ON DELETE CASCADE
  );

  -- Orders
  CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY
    , customer_id INT NOT NULL
    , address_id INT NOT NULL
    , status ENUM(
      'pending'
      , 'processing'
      , 'shipped'
      , 'delivered'
      , 'cancelled'
    ) DEFAULT 'pending'
    , total DECIMAL(12, 2) NOT NULL DEFAULT 0.00
    , created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    , FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
    , FOREIGN KEY (address_id) REFERENCES addresses(address_id)
  );

  -- Order items (one order -> many items)
  CREATE TABLE order_items (
    order_item_id INT AUTO_INCREMENT PRIMARY KEY
    , order_id INT NOT NULL
    , product_id INT NOT NULL
    , quantity INT NOT NULL CHECK (quantity > 0)
    , unit_price DECIMAL(10, 2) NOT NULL CHECK (unit_price >= 0)
    , line_total DECIMAL(12, 2) GENERATED ALWAYS AS (quantity * unit_price) STORED
    , FOREIGN KEY (order_id) REFERENCES orders(order_id)
    ON DELETE CASCADE
    , FOREIGN KEY (product_id) REFERENCES products(product_id)
  );

  -- Payments
  CREATE TABLE payments (
    payment_id INT AUTO_INCREMENT PRIMARY KEY
    , order_id INT NOT NULL
    , amount DECIMAL(12, 2) NOT NULL CHECK (amount >= 0)
    , method ENUM('card', 'paypal', 'bank_transfer') NOT NULL
    , paid_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    , FOREIGN KEY (order_id) REFERENCES orders(order_id)
    ON DELETE CASCADE
  );

  -- Admin / Users (for CRUD app auth if needed)
  CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY
    , username VARCHAR(50) NOT NULL UNIQUE
    , password_hash VARCHAR(255) NOT NULL
    , role ENUM('admin', 'staff') DEFAULT 'staff'
    , created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );

  -- Indexes for performance (common lookup columns)
  CREATE INDEX idx_products_sku
  ON products(sku);
  CREATE INDEX idx_orders_customer
  ON orders(customer_id);
  CREATE INDEX idx_payments_order
  ON payments(order_id);

  -- Sample data
  INSERT INTO
    customers (first_name, last_name, email, phone)
  VALUES
    (
      'John'
      , 'Doe'
      , 'john.doe@example.com'
      , '+254700111222'
    )
    , (
      'Jane'
      , 'Smith'
      , 'jane.smith@example.com'
      , '+254700333444'
    );

  INSERT INTO
    addresses (
      customer_id
      , street
      , city
      , state
      , postal_code
      , country
      , is_default
    )
  VALUES
    (
      1
      , '12 Rose Ave'
      , 'Nairobi'
      , 'Nairobi'
      , '00100'
      , 'Kenya'
      , TRUE
    )
    , (
      2
      , '88 Oud Lane'
      , 'Mombasa'
      , 'Coast'
      , '80100'
      , 'Kenya'
      , TRUE
    );

  INSERT INTO
    products (sku, name, description, price, stock)
  VALUES
    (
      'EL-001'
      , 'Floral Essence 50ml'
      , 'A bouquet of roses and jasmine'
      , 45.00
      , 50
    )
    , (
      'EL-002'
      , 'Ocean Breeze 50ml'
      , 'Fresh aquatic citrus fragrance'
      , 39.50
      , 30
    )
    , (
      'EL-003'
      , 'Mystic Oud 50ml'
      , 'Deep woody & spice notes'
      , 72.00
      , 15
    );

  INSERT INTO
    categories (name, description)
  VALUES
    ('Floral', 'Floral dominant scents')
    , ('Fresh', 'Aquatic and citrusy scents')
    , ('Woody', 'Oud, sandalwood and woody scents');

  INSERT INTO
    product_categories (product_id, category_id)
  VALUES
    (1, 1)
    , (2, 2)
    , (3, 3);

  -- Create one sample order with items and payment
  INSERT INTO
    orders (customer_id, address_id, status, total)
  VALUES
    (1, 1, 'processing', 0.00);
  SET @last_order = LAST_INSERT_ID();

  INSERT INTO
    order_items (order_id, product_id, quantity, unit_price)
  VALUES
    (@last_order, 1, 1, 45.00)
    , (@last_order, 3, 1, 72.00);

  -- Update order total from order_items
  UPDATE
    orders o
  SET o.total = (
    SELECT
      COALESCE(SUM(line_total), 0)
    FROM
      order_items
    WHERE
      order_id = o.order_id
  )
  WHERE
    o.order_id = @last_order;

  INSERT INTO
    payments (order_id, amount, method)
  VALUES
    (
      @last_order
      , (
        SELECT
          total
        FROM
          orders
        WHERE
          order_id = @last_order
      )
      , 'card'
    );

  -- Done