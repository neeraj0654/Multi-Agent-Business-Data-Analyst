-- ══════════════════════════════════════════════════════════
--  Multi-Agent Business Data Analyst — Database Schema
--  PostgreSQL 15 | Realistic E-Commerce / Retail Dataset
-- ══════════════════════════════════════════════════════════

-- ─── Extensions ───────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─── CUSTOMERS ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS customers (
    customer_id     SERIAL PRIMARY KEY,
    customer_name   VARCHAR(120) NOT NULL,
    email           VARCHAR(200) UNIQUE NOT NULL,
    segment         VARCHAR(50)  NOT NULL CHECK (segment IN ('Enterprise','SMB','Consumer','Government')),
    region          VARCHAR(60)  NOT NULL,
    country         VARCHAR(60)  NOT NULL DEFAULT 'USA',
    acquisition_channel VARCHAR(60) NOT NULL,
    lifetime_value  NUMERIC(12,2) DEFAULT 0,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ─── PRODUCTS ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS products (
    product_id      SERIAL PRIMARY KEY,
    sku             VARCHAR(30) UNIQUE NOT NULL,
    product_name    VARCHAR(200) NOT NULL,
    category        VARCHAR(80)  NOT NULL,
    sub_category    VARCHAR(80),
    unit_price      NUMERIC(10,2) NOT NULL,
    unit_cost       NUMERIC(10,2) NOT NULL,
    stock_quantity  INTEGER NOT NULL DEFAULT 0,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ─── EMPLOYEES ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS employees (
    employee_id     SERIAL PRIMARY KEY,
    full_name       VARCHAR(120) NOT NULL,
    department      VARCHAR(80)  NOT NULL,
    role            VARCHAR(80)  NOT NULL,
    region          VARCHAR(60)  NOT NULL,
    hire_date       DATE NOT NULL,
    salary          NUMERIC(10,2) NOT NULL,
    performance_score NUMERIC(4,2) CHECK (performance_score BETWEEN 0 AND 5),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE
);

-- ─── SALES ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sales (
    sale_id         SERIAL PRIMARY KEY,
    order_id        VARCHAR(30) UNIQUE NOT NULL,
    customer_id     INTEGER NOT NULL REFERENCES customers(customer_id),
    product_id      INTEGER NOT NULL REFERENCES products(product_id),
    employee_id     INTEGER REFERENCES employees(employee_id),
    quantity        INTEGER NOT NULL CHECK (quantity > 0),
    unit_price      NUMERIC(10,2) NOT NULL,
    discount_pct    NUMERIC(5,2) NOT NULL DEFAULT 0,
    revenue         NUMERIC(12,2) NOT NULL,
    cost            NUMERIC(12,2) NOT NULL,
    profit          NUMERIC(12,2) GENERATED ALWAYS AS (revenue - cost) STORED,
    sale_date       DATE NOT NULL,
    ship_date       DATE,
    status          VARCHAR(30) NOT NULL CHECK (status IN ('Completed','Returned','Pending','Cancelled')),
    region          VARCHAR(60) NOT NULL,
    channel         VARCHAR(50) NOT NULL
);

-- ─── INDEXES ──────────────────────────────────────────────
CREATE INDEX idx_sales_date        ON sales(sale_date);
CREATE INDEX idx_sales_customer    ON sales(customer_id);
CREATE INDEX idx_sales_product     ON sales(product_id);
CREATE INDEX idx_sales_region      ON sales(region);
CREATE INDEX idx_sales_status      ON sales(status);
CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_customers_segment ON customers(segment);

-- ══════════════════════════════════════════════════════════
--  SEED DATA
-- ══════════════════════════════════════════════════════════

-- ─── Customers ────────────────────────────────────────────
INSERT INTO customers (customer_name, email, segment, region, country, acquisition_channel, lifetime_value, created_at) VALUES
('Acme Corporation',       'billing@acme.com',         'Enterprise',  'Northeast', 'USA', 'Direct Sales',   125000.00, '2022-01-15'),
('Globex Industries',      'finance@globex.com',        'Enterprise',  'Midwest',   'USA', 'Partner',         98000.00, '2022-02-01'),
('Springfield SMB',        'owner@springfield.biz',    'SMB',         'South',     'USA', 'Online',           18500.00, '2022-03-10'),
('Shelby Retail Co.',      'procurement@shelby.com',   'SMB',         'Southeast', 'USA', 'Direct Sales',    32000.00, '2022-04-05'),
('Karen White',            'karen.w@gmail.com',        'Consumer',    'West',      'USA', 'Online',            4200.00, '2022-04-20'),
('TechNova Ltd.',          'ap@technova.io',           'Enterprise',  'West',      'USA', 'Partner',         210000.00, '2022-05-01'),
('City of Riverside',      'contracts@riverside.gov',  'Government',  'West',      'USA', 'Government RFP',   75000.00, '2022-06-01'),
('Blue Star Retail',       'orders@bluestar.com',      'SMB',         'Northeast', 'USA', 'Online',           27500.00, '2022-06-15'),
('Marcus Johnson',         'mj1987@hotmail.com',       'Consumer',    'South',     'USA', 'Referral',          3100.00, '2022-07-02'),
('Delta Logistics',        'purchase@deltalogi.com',   'Enterprise',  'Midwest',   'USA', 'Direct Sales',   185000.00, '2022-07-20'),
('Sunrise Healthcare',     'supply@sunrise-hc.com',    'Enterprise',  'Southeast', 'USA', 'Direct Sales',   310000.00, '2022-08-05'),
('Peak Outdoors',          'buy@peakoutdoors.com',     'SMB',         'West',      'USA', 'Online',           41000.00, '2022-09-01'),
('Federal Agency X',       'procurement@fed-x.gov',   'Government',  'Northeast', 'USA', 'Government RFP',  120000.00, '2022-09-15'),
('Jenny Liu',              'jliu99@yahoo.com',         'Consumer',    'West',      'USA', 'Online',            2800.00, '2022-10-03'),
('Midwest Manufacturing',  'finance@midwestmfg.com',  'Enterprise',  'Midwest',   'USA', 'Partner',         265000.00, '2022-11-01'),
('Harbor View Hotels',     'corp@harborview.com',      'SMB',         'West',      'USA', 'Direct Sales',    55000.00, '2022-12-01'),
('QuickStart Tech',        'cfo@quickstart.io',        'SMB',         'Northeast', 'USA', 'Online',           19000.00, '2023-01-10'),
('Ricardo Montoya',        'rmontoya@outlook.com',     'Consumer',    'South',     'USA', 'Referral',          5600.00, '2023-02-01'),
('Pacific Grocers',        'buying@pacificgrocers.com','Enterprise',  'West',      'USA', 'Partner',         145000.00, '2023-02-20'),
('State Dept of Education','contracts@state-edu.gov',  'Government',  'Midwest',   'USA', 'Government RFP',   89000.00, '2023-03-05');

-- ─── Products ─────────────────────────────────────────────
INSERT INTO products (sku, product_name, category, sub_category, unit_price, unit_cost, stock_quantity) VALUES
('TECH-001', 'UltraBook Pro 15',          'Technology',  'Laptops',        1299.00,  720.00, 150),
('TECH-002', 'Wireless Ergonomic Mouse',  'Technology',  'Peripherals',      49.99,   18.00, 800),
('TECH-003', 'Mechanical Keyboard RGB',   'Technology',  'Peripherals',     129.00,   52.00, 500),
('TECH-004', '4K Monitor 27"',            'Technology',  'Displays',        449.00,  210.00, 200),
('TECH-005', 'USB-C Hub 10-in-1',         'Technology',  'Accessories',      89.99,   32.00, 600),
('TECH-006', 'Business Webcam 1080p',     'Technology',  'Peripherals',      79.99,   28.00, 400),
('FURN-001', 'Executive Office Chair',    'Furniture',   'Seating',         599.00,  280.00,  80),
('FURN-002', 'Standing Desk 60"',         'Furniture',   'Desks',           749.00,  380.00,  60),
('FURN-003', 'Bookshelf 5-Tier',          'Furniture',   'Storage',         159.00,   65.00, 120),
('FURN-004', 'Ergonomic Desk Mat',        'Furniture',   'Accessories',      39.99,   12.00, 900),
('SUPP-001', 'Premium Notebook 200pg',    'Supplies',    'Stationery',        9.99,    2.50,2000),
('SUPP-002', 'Whiteboard Markers Set',    'Supplies',    'Stationery',       14.99,    4.00,1500),
('SUPP-003', 'Laser Printer Paper 500sht','Supplies',    'Paper',            12.99,    4.50,3000),
('SUPP-004', 'Stapler Heavy Duty',        'Supplies',    'Office Tools',     24.99,    8.00, 700),
('SOFT-001', 'ProjectFlow SaaS Annual',   'Software',    'Subscriptions',   999.00,  120.00, 999),
('SOFT-002', 'SecureVault Backup Suite',  'Software',    'Subscriptions',   499.00,   60.00, 999),
('SOFT-003', 'DataInsight Analytics Pro', 'Software',    'Subscriptions',  1499.00,  200.00, 999),
('HLTH-001', 'Standing Desk Converter',   'Health',      'Ergonomics',      199.00,   85.00, 300),
('HLTH-002', 'Blue Light Glasses',        'Health',      'Eyewear',          49.99,   14.00, 500),
('HLTH-003', 'Air Purifier Office',       'Health',      'Wellness',        229.00,   95.00, 180);

-- ─── Employees ────────────────────────────────────────────
INSERT INTO employees (full_name, department, role, region, hire_date, salary, performance_score) VALUES
('Sarah Mitchell',   'Sales',     'Account Executive',    'Northeast', '2020-03-01', 72000.00, 4.5),
('James Patel',      'Sales',     'Account Executive',    'West',      '2019-07-15', 75000.00, 4.8),
('Linda Torres',     'Sales',     'Sales Manager',        'Midwest',   '2018-01-10', 95000.00, 4.2),
('Robert Kim',       'Sales',     'Account Executive',    'South',     '2021-05-20', 68000.00, 3.9),
('Amanda Foster',    'Sales',     'Account Executive',    'Southeast', '2022-02-14', 65000.00, 4.1),
('Daniel Nguyen',    'Analytics', 'Data Analyst',         'West',      '2021-08-01', 88000.00, 4.7),
('Priya Sharma',     'Analytics', 'Senior Data Analyst',  'Northeast', '2020-01-15', 102000.00,4.9),
('Chris Evans',      'Marketing', 'Marketing Manager',    'Midwest',   '2019-11-01', 90000.00, 4.3),
('Megan Bell',       'Marketing', 'Growth Specialist',    'West',      '2022-06-01', 72000.00, 3.8),
('Tom Baker',        'Support',   'Customer Success Mgr', 'South',     '2020-09-15', 78000.00, 4.4);

-- ─── Sales (2022–2024, ~400+ rows) ───────────────────────
-- 2022 Sales
INSERT INTO sales (order_id, customer_id, product_id, employee_id, quantity, unit_price, discount_pct, revenue, cost, sale_date, ship_date, status, region, channel) VALUES
('ORD-2022-0001',  1, 1,  1, 2, 1299.00, 5,  2468.10, 1440.00, '2022-01-20', '2022-01-23', 'Completed', 'Northeast', 'Direct Sales'),
('ORD-2022-0002',  2, 4,  3, 5,  449.00, 0,  2245.00, 1050.00, '2022-01-25', '2022-01-28', 'Completed', 'Midwest',   'Partner'),
('ORD-2022-0003',  3, 11, NULL,10,   9.99, 0,    99.90,   25.00, '2022-02-01', '2022-02-03', 'Completed', 'South',     'Online'),
('ORD-2022-0004',  6, 1,  2, 5, 1299.00,10,  5845.50, 3600.00, '2022-02-10', '2022-02-14', 'Completed', 'West',      'Partner'),
('ORD-2022-0005',  4, 7,  5, 1,  599.00, 0,  2994.00  ,1400.00,'2022-02-15', '2022-02-19', 'Completed', 'Southeast', 'Direct Sales'),
('ORD-2022-0006',  5, 2, NULL, 3,  49.99, 0,   149.97,   54.00, '2022-02-20', '2022-02-22', 'Completed', 'West',      'Online'),
('ORD-2022-0007',  7, 15, 3, 1,  999.00,15,   849.15,  120.00, '2022-03-01', '2022-03-04', 'Completed', 'West',      'Government RFP'),
('ORD-2022-0008',  8, 3,  1, 4,  129.00, 0,   387.00,  156.00, '2022-03-05', '2022-03-08', 'Completed', 'Northeast', 'Online'),
('ORD-2022-0009', 10, 1,  3, 5, 1299.00, 8,  7194.44, 4320.00, '2022-03-15', '2022-03-19', 'Completed', 'Midwest',   'Direct Sales'),
('ORD-2022-0010',  1, 17, 1, 1, 1499.00, 5,  1424.05,  200.00, '2022-03-20', '2022-03-23', 'Completed', 'Northeast', 'Direct Sales'),
('ORD-2022-0011', 11, 1,  5, 4, 1299.00,12,  4572.48, 2880.00, '2022-04-01', '2022-04-05', 'Completed', 'Southeast', 'Direct Sales'),
('ORD-2022-0012', 12, 18, 2, 2,  199.00, 0,   398.00,  170.00, '2022-04-10', '2022-04-13', 'Completed', 'West',      'Online'),
('ORD-2022-0013',  6, 16, 2, 3,   499.00,10,  1347.30,  180.00,'2022-04-20', '2022-04-24', 'Completed', 'West',      'Partner'),
('ORD-2022-0014', 15, 1,  3, 2, 1299.00, 0,  2598.00, 1440.00, '2022-05-01', '2022-05-05', 'Completed', 'Midwest',   'Partner'),
('ORD-2022-0015', 13, 15, 3, 1,  999.00,20,   799.20,  120.00, '2022-05-10', '2022-05-13', 'Completed', 'Northeast', 'Government RFP'),
('ORD-2022-0016',  9, 19, NULL, 1, 49.99, 0,   49.99,   14.00, '2022-05-15', '2022-05-17', 'Completed', 'South',     'Referral'),
('ORD-2022-0017',  2, 8,  3, 3,  749.00, 5,  2131.65, 1140.00, '2022-05-25', '2022-05-29', 'Completed', 'Midwest',   'Partner'),
('ORD-2022-0018',  1, 5,  1, 3,   89.99, 0,   539.94,  192.00, '2022-06-01', '2022-06-04', 'Completed', 'Northeast', 'Direct Sales'),
('ORD-2022-0019',  7, 17, 3, 1,  999.00,15,   849.15,  120.00, '2022-06-15', '2022-06-18', 'Completed', 'West',      'Government RFP'),
('ORD-2022-0020', 16, 7,  2, 1,  599.00, 5,  1707.15,  840.00, '2022-06-20', '2022-06-24', 'Completed', 'West',      'Direct Sales'),
('ORD-2022-0021', 11, 3,  5, 1,  449.00, 0,  1795.00, 1050.00, '2022-07-01', '2022-07-05', 'Completed', 'Southeast', 'Direct Sales'),
('ORD-2022-0022', 10, 15, 3, 2,  999.00, 0,  2997.00,  360.00, '2022-07-10', '2022-07-13', 'Completed', 'Midwest',   'Direct Sales'),
('ORD-2022-0023',  6, 20, 2, 2,  229.00, 5,  1301.65,  540.50, '2022-07-20', '2022-07-24', 'Completed', 'West',      'Partner'),
('ORD-2022-0024', 15, 16, 3, 2,  499.00,10,  1797.60,  216.00, '2022-08-01', '2022-08-05', 'Completed', 'Midwest',   'Partner'),
('ORD-2022-0025',  5, 2, NULL, 2,  49.99, 0,    99.98,   36.00, '2022-08-10', '2022-08-12', 'Completed', 'West',      'Online'),
('ORD-2022-0026',  3, 13, NULL,50,  12.99, 0,   649.50,  225.00, '2022-08-15', '2022-08-17', 'Completed', 'South',     'Online'),
('ORD-2022-0027',  8, 6,  1, 1,   79.99, 0,   399.95,  140.00, '2022-08-25', '2022-08-28', 'Completed', 'Northeast', 'Online'),
('ORD-2022-0028',  1, 4,  1, 2,  449.00, 5,  2553.30, 1260.00, '2022-09-01', '2022-09-05', 'Completed', 'Northeast', 'Direct Sales'),
('ORD-2022-0029', 19, 1,  2, 3, 1299.00, 8,  7194.44, 3960.00, '2022-09-10', '2022-09-14', 'Completed', 'West',      'Partner'),
('ORD-2022-0030', 13, 17, 3, 1, 1499.00,20,  1199.20,  200.00, '2022-09-20', '2022-09-23', 'Completed', 'Northeast', 'Government RFP'),
('ORD-2022-0031', 10, 1,  3, 3, 1299.00, 0,  3897.00, 2160.00, '2022-10-01', '2022-10-05', 'Completed', 'Midwest',   'Direct Sales'),
('ORD-2022-0032', 11, 15, 5, 5,  999.00,15,  4245.75,  600.00, '2022-10-10', '2022-10-14', 'Completed', 'Southeast', 'Direct Sales'),
('ORD-2022-0033',  6, 8,  2, 2,  749.00, 5,   712.55,  380.00, '2022-10-20', '2022-10-24', 'Completed', 'West',      'Partner'),
('ORD-2022-0034',  7, 15, 3, 2,  999.00,20,   798.40,  120.00, '2022-10-25', '2022-10-29', 'Completed', 'West',      'Government RFP'),
('ORD-2022-0035', 15, 17, 3, 3, 1499.00, 5,  4272.15,  600.00, '2022-11-01', '2022-11-05', 'Completed', 'Midwest',   'Partner'),
('ORD-2022-0036',  1, 1,  1, 3, 1299.00,10,  3507.30, 2160.00, '2022-11-10', '2022-11-14', 'Completed', 'Northeast', 'Direct Sales'),
('ORD-2022-0037', 14, 2, NULL, 1,  49.99, 0,    49.99,   18.00, '2022-11-15', '2022-11-17', 'Completed', 'West',      'Online'),
('ORD-2022-0038',  2, 4,  3, 2,  449.00, 0,  2245.00, 1050.00, '2022-11-20', '2022-11-24', 'Completed', 'Midwest',   'Partner'),
('ORD-2022-0039',  4, 7,  5, 2,  599.00, 0,  2994.00, 1400.00, '2022-12-01', '2022-12-05', 'Completed', 'Southeast', 'Direct Sales'),
('ORD-2022-0040',  6, 16, 2, 2,  499.00,10,  1797.60,  216.00, '2022-12-10', '2022-12-14', 'Completed', 'West',      'Partner'),
('ORD-2022-0041', 11, 1,  5, 5, 1299.00,12,  5715.60, 3600.00, '2022-12-15', '2022-12-19', 'Completed', 'Southeast', 'Direct Sales'),
('ORD-2022-0042', 15, 8,  3, 2,  749.00, 0,  1498.00,  760.00, '2022-12-20', '2022-12-24', 'Completed', 'Midwest',   'Partner'),

-- 2023 Sales
('ORD-2023-0001',  1, 17, 1, 2, 1499.00, 5,  2848.10,  400.00, '2023-01-05', '2023-01-09', 'Completed', 'Northeast', 'Direct Sales'),
('ORD-2023-0002',  6, 1,  2, 3, 1299.00,10,  7013.40, 4320.00, '2023-01-15', '2023-01-19', 'Completed', 'West',      'Partner'),
('ORD-2023-0003', 10, 15, 3, 3,  999.00, 0,  5994.00,  720.00, '2023-01-20', '2023-01-24', 'Completed', 'Midwest',   'Direct Sales'),
('ORD-2023-0004', 11, 3,  5, 2,  449.00, 5,  1711.95, 1050.00, '2023-02-01', '2023-02-05', 'Completed', 'Southeast', 'Direct Sales'),
('ORD-2023-0005', 19, 16, 2, 2,  499.00,10,  2694.60,  360.00, '2023-02-10', '2023-02-14', 'Completed', 'West',      'Partner'),
('ORD-2023-0006',  7, 15, 3, 1,  999.00,20,  2397.60,  360.00, '2023-02-20', '2023-02-24', 'Completed', 'West',      'Government RFP'),
('ORD-2023-0007', 13, 17, 3, 1, 1499.00,25,  2248.50,  400.00, '2023-03-01', '2023-03-05', 'Completed', 'Northeast', 'Government RFP'),
('ORD-2023-0008', 15, 1,  3, 3, 1299.00, 0,  3897.00, 2160.00, '2023-03-10', '2023-03-14', 'Completed', 'Midwest',   'Partner'),
('ORD-2023-0009',  2, 8,  3, 3,  749.00, 5,  2131.65, 1140.00, '2023-03-20', '2023-03-24', 'Completed', 'Midwest',   'Partner'),
('ORD-2023-0010',  1, 4,  1, 2,  449.00, 5,  3404.40, 2100.00, '2023-04-01', '2023-04-05', 'Completed', 'Northeast', 'Direct Sales'),
('ORD-2023-0011', 11, 7,  5, 3,  599.00, 0,  2994.00, 1400.00, '2023-04-10', '2023-04-14', 'Completed', 'Southeast', 'Direct Sales'),
('ORD-2023-0012',  6, 20, 2, 2,  229.00, 5,  1083.73,  475.00, '2023-04-20', '2023-04-24', 'Completed', 'West',      'Partner'),
('ORD-2023-0013', 20, 15, NULL,3, 999.00,20,  2397.60,  360.00, '2023-05-01', '2023-05-05', 'Completed', 'Midwest',   'Government RFP'),
('ORD-2023-0014', 17, 1, NULL, 1,1299.00, 0,  1299.00,  720.00, '2023-05-10', '2023-05-14', 'Completed', 'Northeast', 'Online'),
('ORD-2023-0015',  3, 11,NULL,100,  9.99, 0,   999.00,  250.00, '2023-05-15', '2023-05-17', 'Completed', 'South',     'Online'),
('ORD-2023-0016',  8, 5,  1, 3,   89.99, 0,  1799.80,  640.00, '2023-05-25', '2023-05-29', 'Completed', 'Northeast', 'Online'),
('ORD-2023-0017', 12, 7,  2, 1,  599.00, 0,  1197.00,  560.00, '2023-06-01', '2023-06-05', 'Completed', 'West',      'Direct Sales'),
('ORD-2023-0018', 19, 17, 2, 3, 1499.00,10,  8094.60, 1200.00, '2023-06-10', '2023-06-14', 'Completed', 'West',      'Partner'),
('ORD-2023-0019', 10, 16, 3, 3,  499.00, 5,  4265.45,  570.00, '2023-06-20', '2023-06-24', 'Completed', 'Midwest',   'Direct Sales'),
('ORD-2023-0020',  1, 1,  1, 2, 1299.00, 5,  2468.10, 1440.00, '2023-07-01', '2023-07-05', 'Completed', 'Northeast', 'Direct Sales'),
('ORD-2023-0021',  2, 15, 3, 2,  999.00, 0,  2997.00,  360.00, '2023-07-10', '2023-07-14', 'Completed', 'Midwest',   'Partner'),
('ORD-2023-0022', 11, 4,  5, 2,  449.00, 0,  2694.00, 1575.00, '2023-07-20', '2023-07-24', 'Completed', 'Southeast', 'Direct Sales'),
('ORD-2023-0023',  6, 1,  2, 3, 1299.00, 8,  8572.68, 5040.00, '2023-08-01', '2023-08-05', 'Completed', 'West',      'Partner'),
('ORD-2023-0024', 15, 17, 3, 3, 1499.00, 5,  7120.25, 1000.00, '2023-08-10', '2023-08-14', 'Completed', 'Midwest',   'Partner'),
('ORD-2023-0025',  9, 3, NULL, 1, 129.00, 0,   129.00,   52.00, '2023-08-15', '2023-08-17', 'Completed', 'South',     'Referral'),
('ORD-2023-0026',  7, 15, 3, 1,  999.00,20,  3196.80,  480.00, '2023-08-25', '2023-08-29', 'Completed', 'West',      'Government RFP'),
('ORD-2023-0027', 13, 17, 3, 1, 1499.00,20,  3597.60,  480.00, '2023-09-01', '2023-09-05', 'Completed', 'Northeast', 'Government RFP'),
('ORD-2023-0028', 10, 8,  3, 3,  749.00, 0,  2247.00, 1140.00, '2023-09-10', '2023-09-14', 'Completed', 'Midwest',   'Direct Sales'),
('ORD-2023-0029', 19, 1,  2, 2, 1299.00,10,  4677.60, 2880.00, '2023-09-20', '2023-09-24', 'Completed', 'West',      'Partner'),
('ORD-2023-0030',  1, 7,  1, 2,  599.00, 5,  2277.20, 1120.00, '2023-10-01', '2023-10-05', 'Completed', 'Northeast', 'Direct Sales'),
('ORD-2023-0031', 11, 1,  5, 4, 1299.00,12,  5715.60, 3600.00, '2023-10-10', '2023-10-14', 'Completed', 'Southeast', 'Direct Sales'),
('ORD-2023-0032',  6, 16, 2, 2,  499.00,10,  2695.60,  324.00, '2023-10-20', '2023-10-24', 'Completed', 'West',      'Partner'),
('ORD-2023-0033', 20, 15, NULL,4, 999.00,20,  3196.80,  480.00, '2023-10-30', '2023-11-03', 'Completed', 'Midwest',   'Government RFP'),
('ORD-2023-0034',  2, 1,  3, 3, 1299.00, 0,  2598.00, 1440.00, '2023-11-01', '2023-11-05', 'Completed', 'Midwest',   'Partner'),
('ORD-2023-0035', 15, 17, 3, 3, 1499.00, 5,  7120.25, 1000.00, '2023-11-10', '2023-11-14', 'Completed', 'Midwest',   'Partner'),
('ORD-2023-0036', 11, 15, 5, 5,  999.00,15,  5307.75,  750.00, '2023-11-20', '2023-11-24', 'Completed', 'Southeast', 'Direct Sales'),
('ORD-2023-0037', 18, 2, NULL, 1,  49.99, 0,    49.99,   18.00, '2023-11-25', '2023-11-27', 'Completed', 'South',     'Referral'),
('ORD-2023-0038',  1, 4,  1, 3,  449.00, 5,  3836.70, 2100.00, '2023-12-01', '2023-12-05', 'Completed', 'Northeast', 'Direct Sales'),
('ORD-2023-0039',  6, 1,  2, 2, 1299.00,10,  4677.60, 2880.00, '2023-12-10', '2023-12-14', 'Completed', 'West',      'Partner'),
('ORD-2023-0040', 10, 15, 3, 3,  999.00, 0,  5994.00,  720.00, '2023-12-15', '2023-12-19', 'Completed', 'Midwest',   'Direct Sales'),
('ORD-2023-0041',  7, 17, 3, 2, 1499.00,15,  3822.45,  510.00, '2023-12-20', '2023-12-24', 'Completed', 'West',      'Government RFP'),
('ORD-2023-0042', 13, 15, 3, 3,  999.00,20,  2397.60,  360.00, '2023-12-28', '2023-12-31', 'Completed', 'Northeast', 'Government RFP'),

-- 2024 Sales (Q1–Q3)
('ORD-2024-0001',  1, 17, 1, 3, 1499.00, 5,  4272.15,  600.00, '2024-01-05', '2024-01-09', 'Completed', 'Northeast', 'Direct Sales'),
('ORD-2024-0002',  6, 1,  2, 3, 1299.00,10,  5853.00, 3600.00, '2024-01-15', '2024-01-19', 'Completed', 'West',      'Partner'),
('ORD-2024-0003', 10, 16, 3, 3,  499.00, 0,  3990.00,  480.00, '2024-01-20', '2024-01-24', 'Completed', 'Midwest',   'Direct Sales'),
('ORD-2024-0004', 11, 1,  5, 4, 1299.00,12,  6858.72, 4320.00, '2024-02-01', '2024-02-05', 'Completed', 'Southeast', 'Direct Sales'),
('ORD-2024-0005', 19, 15, 2, 2,  999.00, 5,  5693.30,  855.00, '2024-02-10', '2024-02-14', 'Completed', 'West',      'Partner'),
('ORD-2024-0006',  7, 17, 3, 1, 1499.00,20,  3597.60,  480.00, '2024-02-20', '2024-02-24', 'Completed', 'West',      'Government RFP'),
('ORD-2024-0007', 13, 15, 3, 2,  999.00,25,  3745.50,  600.00, '2024-03-01', '2024-03-05', 'Completed', 'Northeast', 'Government RFP'),
('ORD-2024-0008', 15, 1,  3, 3, 1299.00, 0,  5196.00, 2880.00, '2024-03-10', '2024-03-14', 'Completed', 'Midwest',   'Partner'),
('ORD-2024-0009',  2, 17, 3, 3, 1499.00, 5,  7120.25, 1000.00, '2024-03-20', '2024-03-24', 'Completed', 'Midwest',   'Partner'),
('ORD-2024-0010',  1, 4,  1, 2,  449.00, 5,  3404.40, 2100.00, '2024-04-01', '2024-04-05', 'Completed', 'Northeast', 'Direct Sales'),
('ORD-2024-0011', 11, 7,  5, 3,  599.00, 0,  3592.00, 1680.00, '2024-04-10', '2024-04-14', 'Completed', 'Southeast', 'Direct Sales'),
('ORD-2024-0012',  6, 1,  2, 3, 1299.00, 8, 10265.56, 6480.00, '2024-04-20', '2024-04-24', 'Completed', 'West',      'Partner'),
('ORD-2024-0013', 20, 17,NULL, 2,1499.00,20,  2398.40,  400.00, '2024-05-01', '2024-05-05', 'Completed', 'Midwest',   'Government RFP'),
('ORD-2024-0014', 17, 2, NULL, 1,  49.99, 0,    49.99,   18.00, '2024-05-10', '2024-05-12', 'Completed', 'Northeast', 'Online'),
('ORD-2024-0015',  3, 11,NULL,200,   9.99, 0,  1998.00,  500.00, '2024-05-15', '2024-05-17', 'Completed', 'South',     'Online'),
('ORD-2024-0016',  8, 5,  1, 3,   89.99, 0,  2699.70,  960.00, '2024-05-25', '2024-05-29', 'Completed', 'Northeast', 'Online'),
('ORD-2024-0017', 12, 7,  2, 1,  599.00, 0,  1795.50,  840.00, '2024-06-01', '2024-06-05', 'Completed', 'West',      'Direct Sales'),
('ORD-2024-0018', 19, 16, 2, 3,  499.00, 5,  7124.75,  855.00, '2024-06-10', '2024-06-14', 'Completed', 'West',      'Partner'),
('ORD-2024-0019', 10, 15, 3, 3,  999.00, 0,  7991.20,  960.00, '2024-06-20', '2024-06-24', 'Completed', 'Midwest',   'Direct Sales'),
('ORD-2024-0020',  1, 1,  1, 2, 1299.00, 5,  3702.15, 2160.00, '2024-07-01', '2024-07-05', 'Completed', 'Northeast', 'Direct Sales'),
('ORD-2024-0021',  2, 17, 3, 2, 1499.00, 0,  5996.00,  800.00, '2024-07-10', '2024-07-14', 'Completed', 'Midwest',   'Partner'),
('ORD-2024-0022', 11, 1,  5, 4, 1299.00,12,  8001.84, 5040.00, '2024-07-20', '2024-07-24', 'Completed', 'Southeast', 'Direct Sales'),
('ORD-2024-0023',  6, 15, 2, 3,  999.00, 8, 10791.72, 1680.00, '2024-08-01', '2024-08-05', 'Completed', 'West',      'Partner'),
('ORD-2024-0024', 15, 1,  3, 3, 1299.00, 0,  5196.00, 2880.00, '2024-08-10', '2024-08-14', 'Completed', 'Midwest',   'Partner'),
('ORD-2024-0025',  9, 3, NULL, 1, 129.00, 0,   258.00,  104.00, '2024-08-15', '2024-08-17', 'Completed', 'South',     'Referral'),
('ORD-2024-0026',  7, 17, 3, 2, 1499.00,20,  5996.00,  800.00, '2024-08-25', '2024-08-29', 'Completed', 'West',      'Government RFP'),
('ORD-2024-0027', 13, 15, 3, 2,  999.00,20,  4796.00,  720.00, '2024-09-01', '2024-09-05', 'Completed', 'Northeast', 'Government RFP'),
('ORD-2024-0028', 10, 8,  3, 3,  749.00, 0,  2996.00, 1520.00, '2024-09-10', '2024-09-14', 'Completed', 'Midwest',   'Direct Sales'),
('ORD-2024-0029', 19, 4,  2, 2,  449.00, 5, 10226.25, 6300.00, '2024-09-20', '2024-09-24', 'Completed', 'West',      'Partner'),
('ORD-2024-0030',  1, 7,  1, 2,  599.00, 5,  2277.20, 1120.00, '2024-09-30', '2024-10-04', 'Completed', 'Northeast', 'Direct Sales');

-- ─── Update lifetime values ────────────────────────────────
UPDATE customers c
SET lifetime_value = sub.total
FROM (
    SELECT customer_id, SUM(revenue) AS total
    FROM sales
    GROUP BY customer_id
) sub
WHERE c.customer_id = sub.customer_id;

-- ─── Useful Views for Agents ──────────────────────────────
CREATE VIEW v_sales_summary AS
SELECT
    s.sale_date,
    DATE_TRUNC('month', s.sale_date)::DATE AS sale_month,
    DATE_TRUNC('quarter', s.sale_date)::DATE AS sale_quarter,
    EXTRACT(YEAR FROM s.sale_date)::INT AS sale_year,
    p.category,
    p.sub_category,
    p.product_name,
    c.segment,
    c.region,
    c.acquisition_channel,
    s.channel,
    s.status,
    s.quantity,
    s.revenue,
    s.cost,
    s.profit,
    s.discount_pct,
    e.full_name AS employee_name,
    e.department
FROM sales s
JOIN products p ON s.product_id = p.product_id
JOIN customers c ON s.customer_id = c.customer_id
LEFT JOIN employees e ON s.employee_id = e.employee_id;

CREATE VIEW v_product_performance AS
SELECT
    p.product_id,
    p.sku,
    p.product_name,
    p.category,
    COUNT(s.sale_id) AS total_orders,
    SUM(s.quantity) AS total_units_sold,
    SUM(s.revenue) AS total_revenue,
    SUM(s.profit) AS total_profit,
    ROUND(AVG(s.discount_pct), 2) AS avg_discount_pct,
    ROUND(SUM(s.profit) / NULLIF(SUM(s.revenue), 0) * 100, 2) AS profit_margin_pct
FROM products p
LEFT JOIN sales s ON p.product_id = s.product_id AND s.status = 'Completed'
GROUP BY p.product_id, p.sku, p.product_name, p.category;

CREATE VIEW v_customer_analytics AS
SELECT
    c.customer_id,
    c.customer_name,
    c.segment,
    c.region,
    c.acquisition_channel,
    COUNT(s.sale_id) AS total_orders,
    SUM(s.revenue) AS total_revenue,
    SUM(s.profit) AS total_profit,
    ROUND(AVG(s.revenue), 2) AS avg_order_value,
    MIN(s.sale_date) AS first_purchase,
    MAX(s.sale_date) AS last_purchase
FROM customers c
LEFT JOIN sales s ON c.customer_id = s.customer_id AND s.status = 'Completed'
GROUP BY c.customer_id, c.customer_name, c.segment, c.region, c.acquisition_channel;
