-- ============================================================
-- OdiaTraders: seed generic master_products for the 26 new business
-- categories added in Phase 1 (add_catalog_categories.sql must be run
-- FIRST -- this depends on the categories table and the category_id
-- column it adds).
--
-- These are deliberately generic/unbranded entries (e.g. "Smartphone",
-- not "Samsung Galaxy A15") -- matching the existing grocery catalog's
-- style, where an owner picks a generic entry via "Add from Catalog"
-- and names their own brand on top of it (the existing brand-prompt
-- flow in OwnerMasterCatalogScreen). No prices are set here -- pricing
-- is always the owner's own step, never the catalog's.
--
-- No image_url is set (no verified photos exist yet) -- the app's
-- existing icon fallback (CatalogProductImage) handles that gracefully.
--
-- Idempotent: only inserts a (product_name, category) pair that doesn't
-- already exist, so safe to re-run.
-- ============================================================

with new_products (product_name, category, base_unit) as (
  values
    -- Personal Care
    ('Soap', 'Personal Care', 'PCS'),
    ('Shampoo', 'Personal Care', 'BOTTLE'),
    ('Toothpaste', 'Personal Care', 'PCS'),
    -- Household & Cleaning
    ('Detergent Powder', 'Household & Cleaning', 'KG'),
    ('Dishwash Liquid', 'Household & Cleaning', 'BOTTLE'),
    ('Floor Cleaner', 'Household & Cleaning', 'BOTTLE'),
    -- Mobile Phones -- brand-specific, unlike every other category here,
    -- per explicit request: these are common brands sold in the Indian
    -- market, not specific models/storage variants (an owner still picks
    -- their own exact model name when adding one to their shop, same
    -- brand-prompt flow as everywhere else in the catalog).
    ('Samsung Galaxy', 'Mobile Phones', 'PCS'),
    ('Apple iPhone', 'Mobile Phones', 'PCS'),
    ('OnePlus', 'Mobile Phones', 'PCS'),
    ('Vivo', 'Mobile Phones', 'PCS'),
    ('Oppo', 'Mobile Phones', 'PCS'),
    ('Xiaomi Redmi', 'Mobile Phones', 'PCS'),
    ('Realme', 'Mobile Phones', 'PCS'),
    ('Motorola', 'Mobile Phones', 'PCS'),
    -- Mobile Accessories
    ('Mobile Charger', 'Mobile Accessories', 'PCS'),
    ('Earphones', 'Mobile Accessories', 'PCS'),
    ('Power Bank', 'Mobile Accessories', 'PCS'),
    -- Laptops & Computers
    ('Laptop', 'Laptops & Computers', 'PCS'),
    ('Desktop Computer', 'Laptops & Computers', 'PCS'),
    -- Computer Accessories
    ('Keyboard', 'Computer Accessories', 'PCS'),
    ('Mouse', 'Computer Accessories', 'PCS'),
    ('Printer', 'Computer Accessories', 'PCS'),
    -- Electronics
    ('LED Television', 'Electronics', 'PCS'),
    ('Bluetooth Speaker', 'Electronics', 'PCS'),
    -- Home Appliances
    ('Ceiling Fan', 'Home Appliances', 'PCS'),
    ('Refrigerator', 'Home Appliances', 'PCS'),
    ('Washing Machine', 'Home Appliances', 'PCS'),
    -- Furniture
    ('Plastic Chair', 'Furniture', 'PCS'),
    ('Dining Table', 'Furniture', 'PCS'),
    ('Office Chair', 'Furniture', 'PCS'),
    -- Medicines & Pharmacy
    ('Paracetamol Tablets', 'Medicines & Pharmacy', 'STRIP'),
    ('Cough Syrup', 'Medicines & Pharmacy', 'BOTTLE'),
    ('First Aid Kit', 'Medicines & Pharmacy', 'PCS'),
    -- Health & Wellness
    ('Hand Sanitizer', 'Health & Wellness', 'BOTTLE'),
    ('Multivitamin Tablets', 'Health & Wellness', 'STRIP'),
    ('BP Monitor', 'Health & Wellness', 'PCS'),
    -- Building Materials
    ('Red Bricks', 'Building Materials', 'PCS'),
    ('Sand', 'Building Materials', 'TON'),
    ('Concrete Blocks', 'Building Materials', 'PCS'),
    -- Cement
    ('OPC Cement', 'Cement', 'BAG'),
    ('PPC Cement', 'Cement', 'BAG'),
    -- Iron & Steel
    ('TMT Bar 12mm', 'Iron & Steel', 'KG'),
    ('MS Pipe', 'Iron & Steel', 'FEET'),
    ('Steel Sheet', 'Iron & Steel', 'SHEET'),
    -- Hardware
    ('Hammer', 'Hardware', 'PCS'),
    ('Door Lock', 'Hardware', 'PCS'),
    ('Nut Bolt Set', 'Hardware', 'PACK'),
    -- Electrical
    ('LED Bulb', 'Electrical', 'PCS'),
    ('Electrical Wire', 'Electrical', 'ROLL'),
    ('MCB Switch', 'Electrical', 'PCS'),
    -- Plumbing
    ('PVC Pipe', 'Plumbing', 'FEET'),
    ('Water Tap', 'Plumbing', 'PCS'),
    ('Pipe Fitting', 'Plumbing', 'PCS'),
    -- Paints
    ('Wall Paint', 'Paints', 'LTR'),
    ('Primer', 'Paints', 'LTR'),
    ('Paint Brush', 'Paints', 'PCS'),
    -- Tiles & Flooring
    ('Ceramic Floor Tile', 'Tiles & Flooring', 'BOX'),
    ('Vitrified Tile', 'Tiles & Flooring', 'BOX'),
    ('Tile Adhesive', 'Tiles & Flooring', 'BAG'),
    -- Sanitaryware
    ('Wash Basin', 'Sanitaryware', 'PCS'),
    ('Western Toilet', 'Sanitaryware', 'PCS'),
    ('Shower Head', 'Sanitaryware', 'PCS'),
    -- Tools & Equipment
    ('Drill Machine', 'Tools & Equipment', 'PCS'),
    ('Tool Box', 'Tools & Equipment', 'PCS'),
    ('Ladder', 'Tools & Equipment', 'PCS'),
    -- Agriculture & Farming
    ('Fertilizer', 'Agriculture & Farming', 'BAG'),
    ('Pesticide', 'Agriculture & Farming', 'BOTTLE'),
    ('Seeds Packet', 'Agriculture & Farming', 'PACK'),
    -- Stationery
    ('Notebook', 'Stationery', 'PCS'),
    ('Ball Pen', 'Stationery', 'PCS'),
    ('A4 Paper Ream', 'Stationery', 'PACK'),
    -- Clothing & Textiles
    ('Cotton Shirt', 'Clothing & Textiles', 'PCS'),
    ('Fabric Roll', 'Clothing & Textiles', 'ROLL'),
    ('Jeans', 'Clothing & Textiles', 'PCS'),
    -- Footwear
    ('Sports Shoes', 'Footwear', 'PAIR'),
    ('Sandals', 'Footwear', 'PAIR'),
    ('Formal Shoes', 'Footwear', 'PAIR'),
    -- Auto Parts
    ('Car Battery', 'Auto Parts', 'PCS'),
    ('Tyre', 'Auto Parts', 'PCS'),
    ('Oil Filter', 'Auto Parts', 'PCS')
)
insert into master_products (product_name, category, category_id, base_unit, is_active)
select
  np.product_name,
  np.category,
  (select id from categories where parent_id is null and lower(name) = lower(np.category)),
  np.base_unit,
  true
from new_products np
where not exists (
  select 1 from master_products mp
  where lower(mp.product_name) = lower(np.product_name) and lower(mp.category) = lower(np.category)
);
