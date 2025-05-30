-- PostgreSQL Database Initialization Script for Testing
-- This script creates a comprehensive e-commerce database with substantial test data
-- Generated for testing and development purposes

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Drop existing tables if they exist
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS product_reviews CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS addresses CASCADE;
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS inventory_movements CASCADE;
DROP TABLE IF EXISTS suppliers CASCADE;
DROP TABLE IF EXISTS user_sessions CASCADE;
DROP TABLE IF EXISTS payment_methods CASCADE;
DROP TABLE IF EXISTS shipping_methods CASCADE;

-- Create customers table
CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT uuid_generate_v4() UNIQUE,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    date_of_birth DATE,
    gender VARCHAR(10),
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP,
    login_count INTEGER DEFAULT 0,
    email_verified BOOLEAN DEFAULT FALSE,
    marketing_opt_in BOOLEAN DEFAULT FALSE
);

-- Create addresses table
CREATE TABLE addresses (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(id) ON DELETE CASCADE,
    type VARCHAR(20) DEFAULT 'shipping', -- shipping, billing
    street_address VARCHAR(255) NOT NULL,
    apartment VARCHAR(50),
    city VARCHAR(100) NOT NULL,
    state VARCHAR(50) NOT NULL,
    postal_code VARCHAR(20) NOT NULL,
    country VARCHAR(50) NOT NULL DEFAULT 'United States',
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create categories table
CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    parent_id INTEGER REFERENCES categories(id),
    image_url VARCHAR(500),
    is_active BOOLEAN DEFAULT TRUE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create suppliers table
CREATE TABLE suppliers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    contact_email VARCHAR(255),
    contact_phone VARCHAR(20),
    address TEXT,
    country VARCHAR(50),
    rating DECIMAL(3,2) DEFAULT 5.00,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create products table
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    sku VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    short_description TEXT,
    category_id INTEGER REFERENCES categories(id),
    supplier_id INTEGER REFERENCES suppliers(id),
    price DECIMAL(10,2) NOT NULL,
    cost_price DECIMAL(10,2),
    sale_price DECIMAL(10,2),
    weight DECIMAL(8,3),
    dimensions VARCHAR(50),
    color VARCHAR(50),
    size VARCHAR(20),
    brand VARCHAR(100),
    stock_quantity INTEGER DEFAULT 0,
    min_stock_level INTEGER DEFAULT 10,
    max_stock_level INTEGER DEFAULT 1000,
    is_active BOOLEAN DEFAULT TRUE,
    is_featured BOOLEAN DEFAULT FALSE,
    rating DECIMAL(3,2) DEFAULT 0.00,
    review_count INTEGER DEFAULT 0,
    image_url VARCHAR(500),
    tags TEXT[],
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create orders table
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    order_number VARCHAR(50) UNIQUE NOT NULL,
    customer_id INTEGER REFERENCES customers(id),
    status VARCHAR(20) DEFAULT 'pending',
    subtotal DECIMAL(10,2) NOT NULL,
    tax_amount DECIMAL(10,2) DEFAULT 0.00,
    shipping_amount DECIMAL(10,2) DEFAULT 0.00,
    discount_amount DECIMAL(10,2) DEFAULT 0.00,
    total_amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    payment_status VARCHAR(20) DEFAULT 'pending',
    payment_method VARCHAR(50),
    shipping_address_id INTEGER REFERENCES addresses(id),
    billing_address_id INTEGER REFERENCES addresses(id),
    notes TEXT,
    shipped_at TIMESTAMP,
    delivered_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create order_items table
CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES products(id),
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    total_price DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create product_reviews table
CREATE TABLE product_reviews (
    id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
    customer_id INTEGER REFERENCES customers(id) ON DELETE CASCADE,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    title VARCHAR(255),
    comment TEXT,
    is_verified_purchase BOOLEAN DEFAULT FALSE,
    helpful_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create inventory_movements table
CREATE TABLE inventory_movements (
    id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(id),
    movement_type VARCHAR(20) NOT NULL, -- 'in', 'out', 'adjustment'
    quantity INTEGER NOT NULL,
    reference_type VARCHAR(50), -- 'order', 'purchase', 'adjustment'
    reference_id INTEGER,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER REFERENCES customers(id)
);

-- Create audit_logs table
CREATE TABLE audit_logs (
    id SERIAL PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    record_id INTEGER NOT NULL,
    action VARCHAR(10) NOT NULL, -- INSERT, UPDATE, DELETE
    old_values JSONB,
    new_values JSONB,
    changed_by INTEGER REFERENCES customers(id),
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create user_sessions table
CREATE TABLE user_sessions (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(id) ON DELETE CASCADE,
    session_token VARCHAR(255) UNIQUE NOT NULL,
    ip_address INET,
    user_agent TEXT,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create payment_methods table
CREATE TABLE payment_methods (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(id) ON DELETE CASCADE,
    type VARCHAR(20) NOT NULL, -- 'credit_card', 'debit_card', 'paypal'
    last_four VARCHAR(4),
    brand VARCHAR(20),
    expires_month INTEGER,
    expires_year INTEGER,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create shipping_methods table
CREATE TABLE shipping_methods (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    estimated_days INTEGER,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX idx_customers_email ON customers(email);
CREATE INDEX idx_customers_status ON customers(status);
CREATE INDEX idx_customers_created_at ON customers(created_at);
CREATE INDEX idx_addresses_customer_id ON addresses(customer_id);
CREATE INDEX idx_products_category_id ON products(category_id);
CREATE INDEX idx_products_sku ON products(sku);
CREATE INDEX idx_products_is_active ON products(is_active);
CREATE INDEX idx_products_created_at ON products(created_at);
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created_at ON orders(created_at);
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
CREATE INDEX idx_reviews_product_id ON product_reviews(product_id);
CREATE INDEX idx_reviews_customer_id ON product_reviews(customer_id);
CREATE INDEX idx_inventory_product_id ON inventory_movements(product_id);
CREATE INDEX idx_audit_logs_table_record ON audit_logs(table_name, record_id);
CREATE INDEX idx_sessions_customer_id ON user_sessions(customer_id);
CREATE INDEX idx_sessions_token ON user_sessions(session_token);

-- Insert sample categories
INSERT INTO categories (name, slug, description, parent_id, sort_order) VALUES
('Electronics', 'electronics', 'Electronic devices and gadgets', NULL, 1),
('Computers', 'computers', 'Desktop and laptop computers', 1, 1),
('Smartphones', 'smartphones', 'Mobile phones and accessories', 1, 2),
('Audio', 'audio', 'Headphones, speakers, and audio equipment', 1, 3),
('Gaming', 'gaming', 'Gaming consoles and accessories', 1, 4),
('Clothing', 'clothing', 'Apparel and fashion items', NULL, 2),
('Men''s Clothing', 'mens-clothing', 'Clothing for men', 6, 1),
('Women''s Clothing', 'womens-clothing', 'Clothing for women', 6, 2),
('Shoes', 'shoes', 'Footwear for all occasions', 6, 3),
('Home & Garden', 'home-garden', 'Home improvement and garden supplies', NULL, 3),
('Furniture', 'furniture', 'Home and office furniture', 10, 1),
('Kitchen', 'kitchen', 'Kitchen appliances and tools', 10, 2),
('Books', 'books', 'Books and educational materials', NULL, 4),
('Fiction', 'fiction', 'Fiction books and novels', 13, 1),
('Non-Fiction', 'non-fiction', 'Educational and reference books', 13, 2),
('Sports', 'sports', 'Sports equipment and apparel', NULL, 5),
('Outdoor', 'outdoor', 'Outdoor and camping gear', 16, 1),
('Fitness', 'fitness', 'Fitness equipment and accessories', 16, 2),
('Beauty', 'beauty', 'Beauty and personal care products', NULL, 6),
('Skincare', 'skincare', 'Skincare products and treatments', 19, 1);

-- Insert sample suppliers
INSERT INTO suppliers (name, contact_email, contact_phone, address, country, rating) VALUES
('TechCorp Solutions', 'contact@techcorp.com', '+1-555-0101', '123 Tech Street, Silicon Valley, CA 94105', 'United States', 4.8),
('Global Electronics Ltd', 'sales@globalelectronics.com', '+44-20-7946-0958', '45 London Road, Manchester M1 2AB', 'United Kingdom', 4.6),
('Fashion Forward Inc', 'orders@fashionforward.com', '+1-555-0102', '789 Fashion Ave, New York, NY 10018', 'United States', 4.7),
('Home Essentials Co', 'info@homeessentials.com', '+1-555-0103', '456 Home Street, Chicago, IL 60601', 'United States', 4.5),
('Book Publishers United', 'distribution@bpu.com', '+1-555-0104', '321 Publisher Blvd, Austin, TX 78701', 'United States', 4.9),
('Sports Gear Pro', 'wholesale@sportsgear.com', '+1-555-0105', '654 Athletic Way, Denver, CO 80202', 'United States', 4.4),
('Beauty Solutions', 'contact@beautysolutions.com', '+33-1-42-86-83-86', '12 Rue de la Beauté, Paris 75008', 'France', 4.6),
('Asian Electronics', 'export@asianelectronics.com', '+86-21-6887-1234', '88 Innovation Road, Shanghai 200120', 'China', 4.3),
('European Fashion House', 'trade@europeanfashion.com', '+39-02-7200-0001', 'Via della Moda 25, Milano 20121', 'Italy', 4.8),
('Northern Supplies', 'sales@northernsupplies.com', '+1-604-555-0106', '777 Mountain View, Vancouver BC V6B 1A1', 'Canada', 4.5);

-- Function to generate random data
CREATE OR REPLACE FUNCTION random_between(low INT, high INT) 
RETURNS INT AS $$
BEGIN
   RETURN floor(random() * (high - low + 1) + low);
END;
$$ LANGUAGE plpgsql;

-- Insert sample customers (2000 customers)
INSERT INTO customers (email, password_hash, first_name, last_name, phone, date_of_birth, gender, status, email_verified, marketing_opt_in, login_count) 
SELECT 
    'user' || generate_series || '@example.com',
    crypt('password123', gen_salt('bf')),
    (ARRAY['John', 'Jane', 'Michael', 'Sarah', 'David', 'Emily', 'Chris', 'Amanda', 'James', 'Lisa', 'Robert', 'Jessica', 'William', 'Ashley', 'Daniel', 'Nicole', 'Matthew', 'Michelle', 'Andrew', 'Stephanie'])[ceil(random() * 20)],
    (ARRAY['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez', 'Hernandez', 'Lopez', 'Gonzalez', 'Wilson', 'Anderson', 'Thomas', 'Taylor', 'Moore', 'Jackson', 'Martin'])[ceil(random() * 20)],
    '+1-555-' || lpad((random() * 9999)::int::text, 4, '0'),
    '1970-01-01'::date + (random() * 18000)::int,
    (ARRAY['Male', 'Female', 'Other'])[ceil(random() * 3)],
    (ARRAY['active', 'inactive', 'suspended'])[ceil(random() * 3)],
    random() > 0.3,
    random() > 0.4,
    (random() * 100)::int
FROM generate_series(1, 2000);

-- Insert addresses for customers
INSERT INTO addresses (customer_id, type, street_address, apartment, city, state, postal_code, country, is_default)
SELECT 
    c.id,
    (ARRAY['shipping', 'billing'])[ceil(random() * 2)],
    (random() * 9999)::int || ' ' || (ARRAY['Main St', 'Oak Ave', 'Pine Rd', 'Elm Dr', 'Maple Ln', 'Cedar Blvd', 'Birch Way', 'Willow Ct'])[ceil(random() * 8)],
    CASE WHEN random() > 0.7 THEN 'Apt ' || (random() * 50)::int ELSE NULL END,
    (ARRAY['New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix', 'Philadelphia', 'San Antonio', 'San Diego', 'Dallas', 'San Jose', 'Austin', 'Jacksonville', 'Fort Worth', 'Columbus', 'Charlotte', 'Detroit', 'El Paso', 'Memphis', 'Boston', 'Seattle'])[ceil(random() * 20)],
    (ARRAY['NY', 'CA', 'IL', 'TX', 'AZ', 'PA', 'FL', 'OH', 'NC', 'MI', 'TN', 'MA', 'WA', 'GA', 'VA', 'NV', 'OR', 'CO', 'MD', 'MN'])[ceil(random() * 20)],
    lpad((random() * 99999)::int::text, 5, '0'),
    'United States',
    random() > 0.5
FROM customers c, generate_series(1, 2);

-- Insert products (1500 products)
INSERT INTO products (sku, name, slug, description, short_description, category_id, supplier_id, price, cost_price, sale_price, weight, color, size, brand, stock_quantity, min_stock_level, max_stock_level, is_active, is_featured, rating, review_count, tags)
SELECT 
    'SKU-' || lpad(generate_series::text, 6, '0'),
    (ARRAY['Premium', 'Deluxe', 'Professional', 'Standard', 'Basic', 'Ultra', 'Super', 'Mega', 'Advanced', 'Elite'])[ceil(random() * 10)] || ' ' ||
    (ARRAY['Laptop', 'Phone', 'Headphones', 'Speaker', 'Tablet', 'Monitor', 'Keyboard', 'Mouse', 'Camera', 'Watch', 'Shirt', 'Pants', 'Shoes', 'Jacket', 'Dress', 'Sofa', 'Chair', 'Table', 'Lamp', 'Book'])[ceil(random() * 20)] || ' ' ||
    (ARRAY['Model', 'Series', 'Edition', 'Version', 'Pro', 'Max', 'Plus', 'Air', 'Mini', 'XL'])[ceil(random() * 10)] || ' ' || generate_series,
    lower(regexp_replace((ARRAY['Premium', 'Deluxe', 'Professional', 'Standard', 'Basic', 'Ultra', 'Super', 'Mega', 'Advanced', 'Elite'])[ceil(random() * 10)] || '-' ||
    (ARRAY['laptop', 'phone', 'headphones', 'speaker', 'tablet', 'monitor', 'keyboard', 'mouse', 'camera', 'watch', 'shirt', 'pants', 'shoes', 'jacket', 'dress', 'sofa', 'chair', 'table', 'lamp', 'book'])[ceil(random() * 20)] || '-' ||
    (ARRAY['model', 'series', 'edition', 'version', 'pro', 'max', 'plus', 'air', 'mini', 'xl'])[ceil(random() * 10)] || '-' || generate_series, '[^a-z0-9]+', '-', 'g')),
    'High-quality product with excellent features and durability. Perfect for everyday use and professional applications. Manufactured with premium materials.',
    'High-quality product with excellent features.',
    (SELECT id FROM categories ORDER BY random() LIMIT 1),
    (SELECT id FROM suppliers ORDER BY random() LIMIT 1),
    round((random() * 999 + 1)::numeric, 2),
    round((random() * 499 + 1)::numeric, 2),
    CASE WHEN random() > 0.7 THEN round((random() * 799 + 1)::numeric, 2) ELSE NULL END,
    round((random() * 10)::numeric, 3),
    (ARRAY['Black', 'White', 'Red', 'Blue', 'Green', 'Yellow', 'Purple', 'Orange', 'Pink', 'Gray', 'Brown', 'Silver', 'Gold'])[ceil(random() * 13)],
    (ARRAY['XS', 'S', 'M', 'L', 'XL', 'XXL', 'One Size'])[ceil(random() * 7)],
    (ARRAY['Apple', 'Samsung', 'Sony', 'Nike', 'Adidas', 'Microsoft', 'Google', 'Amazon', 'Dell', 'HP', 'Lenovo', 'Canon', 'Nikon', 'IKEA', 'H&M', 'Zara', 'Uniqlo', 'Target', 'Walmart', 'Best Buy'])[ceil(random() * 20)],
    (random() * 500)::int,
    (random() * 20 + 5)::int,
    (random() * 500 + 100)::int,
    random() > 0.1,
    random() > 0.8,
    round((random() * 4 + 1)::numeric, 2),
    (random() * 100)::int,
    ARRAY[(ARRAY['electronics', 'fashion', 'home', 'sports', 'books', 'beauty', 'tech', 'gadgets', 'accessories', 'premium'])[ceil(random() * 10)],
          (ARRAY['bestseller', 'new', 'sale', 'popular', 'trending', 'limited', 'exclusive', 'featured', 'recommended', 'top-rated'])[ceil(random() * 10)]]
FROM generate_series(1, 1500);

-- Insert orders (5000 orders)
INSERT INTO orders (order_number, customer_id, status, subtotal, tax_amount, shipping_amount, discount_amount, total_amount, payment_status, payment_method, shipping_address_id, billing_address_id, notes, shipped_at, delivered_at)
SELECT 
    'ORD-' || to_char(CURRENT_DATE - (random() * 365)::int, 'YYYY') || '-' || lpad(generate_series::text, 6, '0'),
    (SELECT id FROM customers ORDER BY random() LIMIT 1),
    (ARRAY['pending', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded'])[ceil(random() * 6)],
    round((random() * 500 + 10)::numeric, 2),
    round((random() * 50)::numeric, 2),
    round((random() * 25 + 5)::numeric, 2),
    round((random() * 30)::numeric, 2),
    0, -- Will be calculated
    (ARRAY['pending', 'paid', 'failed', 'refunded'])[ceil(random() * 4)],
    (ARRAY['credit_card', 'debit_card', 'paypal', 'apple_pay', 'google_pay', 'bank_transfer'])[ceil(random() * 6)],
    (SELECT id FROM addresses ORDER BY random() LIMIT 1),
    (SELECT id FROM addresses ORDER BY random() LIMIT 1),
    CASE WHEN random() > 0.7 THEN 'Customer requested expedited shipping' ELSE NULL END,
    CASE WHEN random() > 0.4 THEN CURRENT_TIMESTAMP - (random() * 30)::int * INTERVAL '1 day' ELSE NULL END,
    CASE WHEN random() > 0.6 THEN CURRENT_TIMESTAMP - (random() * 20)::int * INTERVAL '1 day' ELSE NULL END
FROM generate_series(1, 5000);

-- Update order totals
UPDATE orders SET total_amount = subtotal + tax_amount + shipping_amount - discount_amount;

-- Insert order items (15000 items)
INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price)
SELECT 
    o.id,
    (SELECT id FROM products ORDER BY random() LIMIT 1),
    (random() * 5 + 1)::int,
    p.price,
    0 -- Will be calculated
FROM orders o
CROSS JOIN generate_series(1, 3) -- Average 3 items per order
JOIN products p ON p.id = (SELECT id FROM products ORDER BY random() LIMIT 1);

-- Update order item totals
UPDATE order_items SET total_price = quantity * unit_price;

-- Insert product reviews (8000 reviews)
INSERT INTO product_reviews (product_id, customer_id, rating, title, comment, is_verified_purchase, helpful_count)
SELECT 
    (SELECT id FROM products ORDER BY random() LIMIT 1),
    (SELECT id FROM customers ORDER BY random() LIMIT 1),
    (random() * 4 + 1)::int,
    (ARRAY['Great product!', 'Excellent quality', 'Good value for money', 'Fast shipping', 'Highly recommended', 'Perfect!', 'Amazing!', 'Love it!', 'Fantastic purchase', 'Outstanding quality', 'Exceeded expectations', 'Solid product', 'Good buy', 'Satisfied customer', 'Worth the price'])[ceil(random() * 15)],
    (ARRAY['This product exceeded my expectations. The quality is outstanding and delivery was fast.',
           'Great value for the price. Would definitely buy again and recommend to others.',
           'Perfect size and color. Exactly what I was looking for. Very satisfied with this purchase.',
           'High quality materials and excellent craftsmanship. Worth every penny.',
           'Fast shipping and product arrived in perfect condition. Seller communication was excellent.',
           'Exactly as described. Product works perfectly and looks great. Highly recommend.',
           'Good product overall but could use some minor improvements in design.',
           'Fantastic quality and great customer service. Will definitely shop here again.',
           'Product is okay but not as good as expected. Still functional and usable.',
           'Outstanding value and quality. This has become one of my favorite purchases.'])[ceil(random() * 10)],
    random() > 0.3,
    (random() * 50)::int
FROM generate_series(1, 8000);

-- Insert inventory movements (10000 movements)
INSERT INTO inventory_movements (product_id, movement_type, quantity, reference_type, reference_id, notes)
SELECT 
    (SELECT id FROM products ORDER BY random() LIMIT 1),
    (ARRAY['in', 'out', 'adjustment'])[ceil(random() * 3)],
    (random() * 100 + 1)::int * CASE WHEN random() > 0.5 THEN 1 ELSE -1 END,
    (ARRAY['order', 'purchase', 'adjustment', 'return', 'damage', 'theft'])[ceil(random() * 6)],
    (random() * 1000)::int,
    (ARRAY['Regular stock movement', 'Damaged goods', 'Customer return', 'Supplier delivery', 'Inventory adjustment', 'Seasonal restock', 'Promotional stock', 'Quality control issue', 'Warehouse transfer', 'Lost item'])[ceil(random() * 10)]
FROM generate_series(1, 10000);

-- Insert user sessions (3000 sessions)
INSERT INTO user_sessions (customer_id, session_token, ip_address, user_agent, expires_at, last_activity)
SELECT 
    (SELECT id FROM customers ORDER BY random() LIMIT 1),
    encode(gen_random_bytes(32), 'hex'),
    ('192.168.' || (random() * 255)::int || '.' || (random() * 255)::int)::inet,
    (ARRAY['Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
           'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
           'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
           'Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X)',
           'Mozilla/5.0 (Android 11; Mobile; rv:68.0) Gecko/68.0 Firefox/88.0'])[ceil(random() * 5)],
    CURRENT_TIMESTAMP + (random() * 30)::int * INTERVAL '1 day',
    CURRENT_TIMESTAMP - (random() * 7)::int * INTERVAL '1 day'
FROM generate_series(1, 3000);

-- Insert payment methods (4000 payment methods)
INSERT INTO payment_methods (customer_id, type, last_four, brand, expires_month, expires_year, is_default)
SELECT 
    c.id,
    (ARRAY['credit_card', 'debit_card', 'paypal'])[ceil(random() * 3)],
    lpad((random() * 9999)::int::text, 4, '0'),
    (ARRAY['Visa', 'Mastercard', 'American Express', 'Discover', 'PayPal'])[ceil(random() * 5)],
    (random() * 11 + 1)::int,
    (random() * 10 + 2024)::int,
    random() > 0.7
FROM customers c, generate_series(1, 2);

-- Insert shipping methods
INSERT INTO shipping_methods (name, description, price, estimated_days, is_active) VALUES
('Standard Shipping', 'Regular delivery within 5-7 business days', 9.99, 7, true),
('Express Shipping', 'Fast delivery within 2-3 business days', 19.99, 3, true),
('Overnight Shipping', 'Next business day delivery', 39.99, 1, true),
('Free Standard Shipping', 'Free shipping for orders over $50', 0.00, 7, true),
('Economy Shipping', 'Budget shipping option, 7-10 business days', 4.99, 10, true),
('International Standard', 'International shipping, 10-15 business days', 29.99, 15, true),
('International Express', 'Fast international shipping, 3-5 business days', 59.99, 5, true),
('Local Pickup', 'Pickup from store location', 0.00, 0, true),
('Same Day Delivery', 'Delivery within same day (select areas)', 24.99, 0, true),
('Two Day Shipping', 'Delivery within 2 business days', 14.99, 2, true);

-- Insert audit logs (5000 audit entries)
INSERT INTO audit_logs (table_name, record_id, action, old_values, new_values, changed_by, ip_address, user_agent)
SELECT 
    (ARRAY['customers', 'orders', 'products', 'order_items', 'addresses'])[ceil(random() * 5)],
    (random() * 1000 + 1)::int,
    (ARRAY['INSERT', 'UPDATE', 'DELETE'])[ceil(random() * 3)],
    '{"field": "old_value"}'::jsonb,
    '{"field": "new_value"}'::jsonb,
    (SELECT id FROM customers ORDER BY random() LIMIT 1),
    ('10.0.' || (random() * 255)::int || '.' || (random() * 255)::int)::inet,
    (ARRAY['Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
           'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
           'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'])[ceil(random() * 3)]
FROM generate_series(1, 5000);

-- Create some database functions for common operations
CREATE OR REPLACE FUNCTION get_customer_order_total(customer_id_param INTEGER)
RETURNS DECIMAL(10,2) AS $$
DECLARE
    total DECIMAL(10,2);
BEGIN
    SELECT COALESCE(SUM(total_amount), 0) 
    INTO total 
    FROM orders 
    WHERE customer_id = customer_id_param AND status != 'cancelled';
    
    RETURN total;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_product_rating(product_id_param INTEGER)
RETURNS VOID AS $$
DECLARE
    avg_rating DECIMAL(3,2);
    review_cnt INTEGER;
BEGIN
    SELECT COALESCE(AVG(rating), 0), COUNT(*)
    INTO avg_rating, review_cnt
    FROM product_reviews 
    WHERE product_id = product_id_param;
    
    UPDATE products 
    SET rating = avg_rating, review_count = review_cnt 
    WHERE id = product_id_param;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_low_stock_products(threshold INTEGER DEFAULT 10)
RETURNS TABLE(id INTEGER, name VARCHAR(255), sku VARCHAR(50), stock_quantity INTEGER, min_stock_level INTEGER) AS $$
BEGIN
    RETURN QUERY
    SELECT p.id, p.name, p.sku, p.stock_quantity, p.min_stock_level
    FROM products p
    WHERE p.stock_quantity <= threshold AND p.is_active = true
    ORDER BY p.stock_quantity ASC;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for automatic updates
CREATE OR REPLACE FUNCTION update_modified_time()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER customers_update_trigger
    BEFORE UPDATE ON customers
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_time();

CREATE TRIGGER products_update_trigger
    BEFORE UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_time();

CREATE TRIGGER orders_update_trigger
    BEFORE UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_time();

-- Create views for common queries
CREATE VIEW customer_order_summary AS
SELECT 
    c.id,
    c.email,
    c.first_name,
    c.last_name,
    COUNT(o.id) as total_orders,
    COALESCE(SUM(o.total_amount), 0) as total_spent,
    MAX(o.created_at) as last_order_date,
    c.created_at as customer_since
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
GROUP BY c.id, c.email, c.first_name, c.last_name, c.created_at;

CREATE VIEW product_performance AS
SELECT 
    p.id,
    p.name,
    p.sku,
    p.price,
    p.stock_quantity,
    p.rating,
    p.review_count,
    COALESCE(SUM(oi.quantity), 0) as total_sold,
    COALESCE(SUM(oi.total_price), 0) as total_revenue,
    c.name as category_name
FROM products p
LEFT JOIN order_items oi ON p.id = oi.product_id
LEFT JOIN categories c ON p.category_id = c.id
GROUP BY p.id, p.name, p.sku, p.price, p.stock_quantity, p.rating, p.review_count, c.name;

CREATE VIEW monthly_sales_report AS
SELECT 
    DATE_TRUNC('month', created_at) as month,
    COUNT(*) as total_orders,
    SUM(total_amount) as total_revenue,
    AVG(total_amount) as average_order_value,
    COUNT(DISTINCT customer_id) as unique_customers
FROM orders
WHERE status != 'cancelled'
GROUP BY DATE_TRUNC('month', created_at)
ORDER BY month DESC;

-- Update product ratings based on reviews
UPDATE products SET rating = subquery.avg_rating, review_count = subquery.review_cnt
FROM (
    SELECT 
        product_id, 
        ROUND(AVG(rating)::numeric, 2) as avg_rating,
        COUNT(*) as review_cnt
    FROM product_reviews 
    GROUP BY product_id
) AS subquery
WHERE products.id = subquery.product_id;

-- Final data integrity checks and cleanup
UPDATE customers SET last_login = created_at + (random() * 365)::int * INTERVAL '1 day' WHERE last_login IS NULL;
UPDATE products SET sale_price = NULL WHERE sale_price >= price;
UPDATE addresses SET is_default = false;
UPDATE addresses SET is_default = true WHERE id IN (
    SELECT DISTINCT ON (customer_id) id 
    FROM addresses 
    ORDER BY customer_id, created_at ASC
);

-- Create additional indexes for performance
CREATE INDEX idx_orders_total_amount ON orders(total_amount);
CREATE INDEX idx_products_price ON products(price);
CREATE INDEX idx_products_rating ON products(rating);
CREATE INDEX idx_customers_last_login ON customers(last_login);
CREATE INDEX idx_order_items_total_price ON order_items(total_price);
CREATE INDEX idx_reviews_rating ON product_reviews(rating);
CREATE INDEX idx_inventory_created_at ON inventory_movements(created_at);

-- Insert additional sample data for comprehensive testing
-- More customer data with realistic patterns
INSERT INTO customers (email, password_hash, first_name, last_name, phone, date_of_birth, gender, status, email_verified, marketing_opt_in, login_count)
SELECT 
    'premium' || generate_series || '@example.com',
    crypt('premium123', gen_salt('bf')),
    (ARRAY['Alexander', 'Isabella', 'Christopher', 'Sophia', 'Benjamin', 'Olivia', 'Nicholas', 'Emma', 'Jonathan', 'Ava'])[ceil(random() * 10)],
    (ARRAY['Anderson', 'Thompson', 'White', 'Harris', 'Clark', 'Lewis', 'Robinson', 'Walker', 'Perez', 'Hall'])[ceil(random() * 10)],
    '+1-800-' || lpad((random() * 9999)::int::text, 4, '0'),
    '1985-01-01'::date + (random() * 10000)::int,
    (ARRAY['Male', 'Female'])[ceil(random() * 2)],
    'active',
    true,
    true,
    (random() * 500 + 50)::int
FROM generate_series(1, 500);

-- Grant appropriate permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO PUBLIC;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO PUBLIC;

-- Analyze tables for better query performance
ANALYZE customers;
ANALYZE products;
ANALYZE orders;
ANALYZE order_items;
ANALYZE product_reviews;
ANALYZE addresses;
ANALYZE categories;
ANALYZE suppliers;
ANALYZE inventory_movements;
ANALYZE audit_logs;
ANALYZE user_sessions;
ANALYZE payment_methods;
ANALYZE shipping_methods;

-- Final summary statistics
SELECT 'Database initialization complete!' as status;
SELECT 'Total customers: ' || COUNT(*) as customer_count FROM customers;
SELECT 'Total products: ' || COUNT(*) as product_count FROM products;
SELECT 'Total orders: ' || COUNT(*) as order_count FROM orders;
SELECT 'Total order items: ' || COUNT(*) as order_item_count FROM order_items;
SELECT 'Total reviews: ' || COUNT(*) as review_count FROM product_reviews;
SELECT 'Total audit logs: ' || COUNT(*) as audit_log_count FROM audit_logs;

COMMIT;
