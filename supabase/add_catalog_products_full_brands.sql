-- ============================================================
-- OdiaTraders: replace the generic Phase 1 catalog entries (one per
-- product type, e.g. "Wall Paint") with specific, well-known brands
-- (e.g. "Asian Paints Wall Paint", "Berger Wall Paint", ...) across
-- every non-grocery category -- per request.
--
-- Mobile Phones is untouched here (already brand-specific from
-- fix_mobile_phones_catalog.sql). Grocery & Daily Essentials, Fruits &
-- Vegetables, and Beverages are untouched -- that catalog already
-- existed before Phase 1 and isn't part of this request.
--
-- Commodity items with no meaningful wholesale brand (bricks, sand,
-- fabric, nuts & bolts, ladders, tile adhesive, pipe fittings, seeds,
-- generic furniture) are deliberately kept as single generic entries
-- rather than inventing brands that don't reflect how they're actually
-- sold.
--
-- Only deletes a master_products row if no owner has linked it into
-- their shop yet (same safety check as fix_mobile_phones_catalog.sql),
-- so re-running this after real owners start using the catalog won't
-- orphan anyone's product. Safe to re-run.
-- ============================================================

delete from master_products mp
where mp.category in (
  'Personal Care', 'Household & Cleaning', 'Mobile Accessories',
  'Laptops & Computers', 'Computer Accessories', 'Electronics',
  'Home Appliances', 'Furniture', 'Medicines & Pharmacy', 'Health & Wellness',
  'Building Materials', 'Cement', 'Iron & Steel', 'Hardware', 'Electrical',
  'Plumbing', 'Paints', 'Tiles & Flooring', 'Sanitaryware', 'Tools & Equipment',
  'Agriculture & Farming', 'Stationery', 'Clothing & Textiles', 'Footwear', 'Auto Parts'
)
and not exists (select 1 from products p where p.master_product_id = mp.id);

with new_products (product_name, category, base_unit) as (
  values
    -- Personal Care
    ('Lux Soap', 'Personal Care', 'PCS'),
    ('Dove Soap', 'Personal Care', 'PCS'),
    ('Lifebuoy Soap', 'Personal Care', 'PCS'),
    ('Santoor Soap', 'Personal Care', 'PCS'),
    ('Head & Shoulders Shampoo', 'Personal Care', 'BOTTLE'),
    ('Sunsilk Shampoo', 'Personal Care', 'BOTTLE'),
    ('Clinic Plus Shampoo', 'Personal Care', 'BOTTLE'),
    ('Colgate Toothpaste', 'Personal Care', 'PCS'),
    ('Pepsodent Toothpaste', 'Personal Care', 'PCS'),
    ('Closeup Toothpaste', 'Personal Care', 'PCS'),

    -- Household & Cleaning
    ('Surf Excel Detergent', 'Household & Cleaning', 'KG'),
    ('Ariel Detergent', 'Household & Cleaning', 'KG'),
    ('Tide Detergent', 'Household & Cleaning', 'KG'),
    ('Rin Detergent', 'Household & Cleaning', 'KG'),
    ('Vim Dishwash Liquid', 'Household & Cleaning', 'BOTTLE'),
    ('Pril Dishwash Liquid', 'Household & Cleaning', 'BOTTLE'),
    ('Exo Dishwash Bar', 'Household & Cleaning', 'PCS'),
    ('Lizol Floor Cleaner', 'Household & Cleaning', 'BOTTLE'),
    ('Harpic Toilet Cleaner', 'Household & Cleaning', 'BOTTLE'),
    ('Domex Floor Cleaner', 'Household & Cleaning', 'BOTTLE'),

    -- Mobile Accessories
    ('Samsung Charger', 'Mobile Accessories', 'PCS'),
    ('Apple Charger', 'Mobile Accessories', 'PCS'),
    ('Mi Charger', 'Mobile Accessories', 'PCS'),
    ('Anker Charger', 'Mobile Accessories', 'PCS'),
    ('boAt Earphones', 'Mobile Accessories', 'PCS'),
    ('JBL Earphones', 'Mobile Accessories', 'PCS'),
    ('Mi Earphones', 'Mobile Accessories', 'PCS'),
    ('Mi Power Bank', 'Mobile Accessories', 'PCS'),
    ('boAt Power Bank', 'Mobile Accessories', 'PCS'),
    ('Ambrane Power Bank', 'Mobile Accessories', 'PCS'),
    ('Mobile Case', 'Mobile Accessories', 'PCS'),
    ('Screen Protector', 'Mobile Accessories', 'PCS'),

    -- Laptops & Computers
    ('HP Laptop', 'Laptops & Computers', 'PCS'),
    ('Dell Laptop', 'Laptops & Computers', 'PCS'),
    ('Lenovo Laptop', 'Laptops & Computers', 'PCS'),
    ('Asus Laptop', 'Laptops & Computers', 'PCS'),
    ('Acer Laptop', 'Laptops & Computers', 'PCS'),
    ('HP Desktop', 'Laptops & Computers', 'PCS'),
    ('Dell Desktop', 'Laptops & Computers', 'PCS'),
    ('Lenovo Desktop', 'Laptops & Computers', 'PCS'),

    -- Computer Accessories
    ('Logitech Keyboard', 'Computer Accessories', 'PCS'),
    ('HP Keyboard', 'Computer Accessories', 'PCS'),
    ('Logitech Mouse', 'Computer Accessories', 'PCS'),
    ('HP Mouse', 'Computer Accessories', 'PCS'),
    ('HP Printer', 'Computer Accessories', 'PCS'),
    ('Canon Printer', 'Computer Accessories', 'PCS'),
    ('Epson Printer', 'Computer Accessories', 'PCS'),
    ('Samsung Monitor', 'Computer Accessories', 'PCS'),
    ('LG Monitor', 'Computer Accessories', 'PCS'),
    ('Dell Monitor', 'Computer Accessories', 'PCS'),

    -- Electronics
    ('Samsung LED TV', 'Electronics', 'PCS'),
    ('LG LED TV', 'Electronics', 'PCS'),
    ('Sony LED TV', 'Electronics', 'PCS'),
    ('Mi LED TV', 'Electronics', 'PCS'),
    ('JBL Bluetooth Speaker', 'Electronics', 'PCS'),
    ('boAt Bluetooth Speaker', 'Electronics', 'PCS'),
    ('Sony Bluetooth Speaker', 'Electronics', 'PCS'),
    ('Canon Camera', 'Electronics', 'PCS'),
    ('Nikon Camera', 'Electronics', 'PCS'),
    ('JBL Soundbar', 'Electronics', 'PCS'),

    -- Home Appliances
    ('Havells Ceiling Fan', 'Home Appliances', 'PCS'),
    ('Crompton Ceiling Fan', 'Home Appliances', 'PCS'),
    ('Orient Ceiling Fan', 'Home Appliances', 'PCS'),
    ('Bajaj Ceiling Fan', 'Home Appliances', 'PCS'),
    ('LG Refrigerator', 'Home Appliances', 'PCS'),
    ('Samsung Refrigerator', 'Home Appliances', 'PCS'),
    ('Whirlpool Refrigerator', 'Home Appliances', 'PCS'),
    ('LG Washing Machine', 'Home Appliances', 'PCS'),
    ('Samsung Washing Machine', 'Home Appliances', 'PCS'),
    ('IFB Washing Machine', 'Home Appliances', 'PCS'),
    ('Bajaj Mixer Grinder', 'Home Appliances', 'PCS'),
    ('Preethi Mixer Grinder', 'Home Appliances', 'PCS'),

    -- Furniture
    ('Nilkamal Plastic Chair', 'Furniture', 'PCS'),
    ('Supreme Plastic Chair', 'Furniture', 'PCS'),
    ('Godrej Interio Office Chair', 'Furniture', 'PCS'),
    ('Featherlite Office Chair', 'Furniture', 'PCS'),
    ('Dining Table', 'Furniture', 'PCS'),
    ('Sofa Set', 'Furniture', 'PCS'),
    ('Wardrobe', 'Furniture', 'PCS'),
    ('Bed', 'Furniture', 'PCS'),

    -- Medicines & Pharmacy
    ('Crocin Tablets', 'Medicines & Pharmacy', 'STRIP'),
    ('Dolo 650 Tablets', 'Medicines & Pharmacy', 'STRIP'),
    ('Calpol Tablets', 'Medicines & Pharmacy', 'STRIP'),
    ('Benadryl Cough Syrup', 'Medicines & Pharmacy', 'BOTTLE'),
    ('Corex Cough Syrup', 'Medicines & Pharmacy', 'BOTTLE'),
    ('Ascoril Cough Syrup', 'Medicines & Pharmacy', 'BOTTLE'),
    ('First Aid Kit', 'Medicines & Pharmacy', 'PCS'),
    ('Dr. Trust Thermometer', 'Medicines & Pharmacy', 'PCS'),
    ('Omron Thermometer', 'Medicines & Pharmacy', 'PCS'),

    -- Health & Wellness
    ('Dettol Hand Sanitizer', 'Health & Wellness', 'BOTTLE'),
    ('Savlon Hand Sanitizer', 'Health & Wellness', 'BOTTLE'),
    ('Revital Multivitamin', 'Health & Wellness', 'STRIP'),
    ('Supradyn Multivitamin', 'Health & Wellness', 'STRIP'),
    ('Zincovit Multivitamin', 'Health & Wellness', 'STRIP'),
    ('Omron BP Monitor', 'Health & Wellness', 'PCS'),
    ('Dr. Trust BP Monitor', 'Health & Wellness', 'PCS'),
    ('MuscleBlaze Protein Powder', 'Health & Wellness', 'PCS'),

    -- Building Materials (kept generic -- genuinely unbranded wholesale)
    ('Red Bricks', 'Building Materials', 'PCS'),
    ('Sand', 'Building Materials', 'TON'),
    ('Concrete Blocks', 'Building Materials', 'PCS'),
    ('Aggregates', 'Building Materials', 'TON'),

    -- Cement
    ('UltraTech Cement', 'Cement', 'BAG'),
    ('ACC Cement', 'Cement', 'BAG'),
    ('Ambuja Cement', 'Cement', 'BAG'),
    ('Dalmia Cement', 'Cement', 'BAG'),
    ('Shree Cement', 'Cement', 'BAG'),
    ('JK Cement', 'Cement', 'BAG'),

    -- Iron & Steel
    ('Tata Tiscon TMT Bar', 'Iron & Steel', 'KG'),
    ('JSW TMT Bar', 'Iron & Steel', 'KG'),
    ('SAIL TMT Bar', 'Iron & Steel', 'KG'),
    ('Jindal Panther TMT Bar', 'Iron & Steel', 'KG'),
    ('MS Pipe', 'Iron & Steel', 'FEET'),
    ('Steel Sheet', 'Iron & Steel', 'SHEET'),

    -- Hardware
    ('Stanley Hammer', 'Hardware', 'PCS'),
    ('Taparia Hammer', 'Hardware', 'PCS'),
    ('Godrej Door Lock', 'Hardware', 'PCS'),
    ('Link Door Lock', 'Hardware', 'PCS'),
    ('Nut Bolt Set', 'Hardware', 'PACK'),

    -- Electrical
    ('Philips LED Bulb', 'Electrical', 'PCS'),
    ('Havells LED Bulb', 'Electrical', 'PCS'),
    ('Syska LED Bulb', 'Electrical', 'PCS'),
    ('Bajaj LED Bulb', 'Electrical', 'PCS'),
    ('Havells Wire', 'Electrical', 'ROLL'),
    ('Polycab Wire', 'Electrical', 'ROLL'),
    ('Finolex Wire', 'Electrical', 'ROLL'),
    ('Havells MCB', 'Electrical', 'PCS'),
    ('Legrand MCB', 'Electrical', 'PCS'),
    ('Anchor Switch', 'Electrical', 'PCS'),

    -- Plumbing
    ('Finolex PVC Pipe', 'Plumbing', 'FEET'),
    ('Supreme PVC Pipe', 'Plumbing', 'FEET'),
    ('Astral PVC Pipe', 'Plumbing', 'FEET'),
    ('Jaquar Water Tap', 'Plumbing', 'PCS'),
    ('Cera Water Tap', 'Plumbing', 'PCS'),
    ('Hindware Water Tap', 'Plumbing', 'PCS'),
    ('Pipe Fitting', 'Plumbing', 'PCS'),

    -- Paints
    ('Asian Paints Wall Paint', 'Paints', 'LTR'),
    ('Berger Wall Paint', 'Paints', 'LTR'),
    ('Nerolac Wall Paint', 'Paints', 'LTR'),
    ('Dulux Wall Paint', 'Paints', 'LTR'),
    ('Asian Paints Primer', 'Paints', 'LTR'),
    ('Paint Brush', 'Paints', 'PCS'),
    ('Paint Roller', 'Paints', 'PCS'),

    -- Tiles & Flooring
    ('Kajaria Ceramic Tile', 'Tiles & Flooring', 'BOX'),
    ('Somany Ceramic Tile', 'Tiles & Flooring', 'BOX'),
    ('Johnson Floor Tile', 'Tiles & Flooring', 'BOX'),
    ('Kajaria Vitrified Tile', 'Tiles & Flooring', 'BOX'),
    ('Orient Bell Vitrified Tile', 'Tiles & Flooring', 'BOX'),
    ('Tile Adhesive', 'Tiles & Flooring', 'BAG'),

    -- Sanitaryware
    ('Hindware Wash Basin', 'Sanitaryware', 'PCS'),
    ('Cera Wash Basin', 'Sanitaryware', 'PCS'),
    ('Parryware Wash Basin', 'Sanitaryware', 'PCS'),
    ('Hindware Western Toilet', 'Sanitaryware', 'PCS'),
    ('Cera Western Toilet', 'Sanitaryware', 'PCS'),
    ('Jaquar Western Toilet', 'Sanitaryware', 'PCS'),
    ('Jaquar Shower Head', 'Sanitaryware', 'PCS'),
    ('Cera Shower Head', 'Sanitaryware', 'PCS'),

    -- Tools & Equipment
    ('Bosch Drill Machine', 'Tools & Equipment', 'PCS'),
    ('Black+Decker Drill Machine', 'Tools & Equipment', 'PCS'),
    ('Makita Drill Machine', 'Tools & Equipment', 'PCS'),
    ('Stanley Tool Box', 'Tools & Equipment', 'PCS'),
    ('Taparia Tool Box', 'Tools & Equipment', 'PCS'),
    ('Ladder', 'Tools & Equipment', 'PCS'),

    -- Agriculture & Farming
    ('IFFCO Fertilizer', 'Agriculture & Farming', 'BAG'),
    ('Coromandel Fertilizer', 'Agriculture & Farming', 'BAG'),
    ('Chambal Fertilizer', 'Agriculture & Farming', 'BAG'),
    ('Bayer Pesticide', 'Agriculture & Farming', 'BOTTLE'),
    ('UPL Pesticide', 'Agriculture & Farming', 'BOTTLE'),
    ('Dhanuka Pesticide', 'Agriculture & Farming', 'BOTTLE'),
    ('Mahyco Seeds', 'Agriculture & Farming', 'PACK'),

    -- Stationery
    ('Classmate Notebook', 'Stationery', 'PCS'),
    ('Navneet Notebook', 'Stationery', 'PCS'),
    ('Cello Ball Pen', 'Stationery', 'PCS'),
    ('Reynolds Ball Pen', 'Stationery', 'PCS'),
    ('Flair Ball Pen', 'Stationery', 'PCS'),
    ('JK Copier A4 Paper', 'Stationery', 'PACK'),
    ('Century A4 Paper', 'Stationery', 'PACK'),

    -- Clothing & Textiles (kept generic -- wholesale fabric trading isn't brand-based)
    ('Cotton Shirt', 'Clothing & Textiles', 'PCS'),
    ('Fabric Roll', 'Clothing & Textiles', 'ROLL'),
    ('Jeans', 'Clothing & Textiles', 'PCS'),

    -- Footwear
    ('Nike Sports Shoes', 'Footwear', 'PAIR'),
    ('Adidas Sports Shoes', 'Footwear', 'PAIR'),
    ('Puma Sports Shoes', 'Footwear', 'PAIR'),
    ('Sparx Sports Shoes', 'Footwear', 'PAIR'),
    ('Bata Sandals', 'Footwear', 'PAIR'),
    ('Paragon Sandals', 'Footwear', 'PAIR'),
    ('Relaxo Sandals', 'Footwear', 'PAIR'),
    ('Bata Formal Shoes', 'Footwear', 'PAIR'),
    ('Red Chief Formal Shoes', 'Footwear', 'PAIR'),
    ('Woodland Formal Shoes', 'Footwear', 'PAIR'),

    -- Auto Parts
    ('Exide Car Battery', 'Auto Parts', 'PCS'),
    ('Amaron Car Battery', 'Auto Parts', 'PCS'),
    ('MRF Tyre', 'Auto Parts', 'PCS'),
    ('CEAT Tyre', 'Auto Parts', 'PCS'),
    ('Apollo Tyre', 'Auto Parts', 'PCS'),
    ('JK Tyre', 'Auto Parts', 'PCS'),
    ('Bosch Oil Filter', 'Auto Parts', 'PCS'),
    ('Mahle Oil Filter', 'Auto Parts', 'PCS')
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
