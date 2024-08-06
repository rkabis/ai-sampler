CREATE TABLE vehicles (
    plateNumber VARCHAR(20) PRIMARY KEY,
    type VARCHAR(50),
    createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    editedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO vehicles (plateNumber, type, createdAt, editedAt) VALUES
('ABC123', 'truck', '2024-01-01 10:00:00', '2024-01-01 10:00:00'),
('DEF456', 'car', '2024-02-01 11:00:00', '2024-02-01 11:00:00'),
('GHI789', 'motorbike', '2024-03-01 12:00:00', '2024-03-01 12:00:00'),
('JKL012', 'truck', '2024-04-01 13:00:00', '2024-04-01 13:00:00'),
('MNO345', 'car', '2024-05-01 14:00:00', '2024-05-01 14:00:00'),
('PQR678', 'motorbike', '2024-06-01 15:00:00', '2024-06-01 15:00:00'),
('STU901', 'truck', '2024-07-01 16:00:00', '2024-07-01 16:00:00'),
('VWX234', 'car', '2024-08-01 17:00:00', '2024-08-01 17:00:00'),
('YZA567', 'motorbike', '2024-09-01 18:00:00', '2024-09-01 18:00:00'),
('BCD890', 'truck', '2024-10-01 19:00:00', '2024-10-01 19:00:00');

select * from vehicles;

CREATE EXTENSION postgis;

CREATE TABLE locations (
    locationID SERIAL PRIMARY KEY,
    name VARCHAR(100),
    createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    editedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    coordinates GEOMETRY(POLYGON, 4326)
);

INSERT INTO locations (name, coordinates) VALUES
('Location 1', ST_GeomFromText('POLYGON((120.9822 14.6042, 120.9822 14.6142, 120.9922 14.6142, 120.9922 14.6042, 120.9822 14.6042))', 4326)),
('Location 2', ST_GeomFromText('POLYGON((120.9722 14.5942, 120.9722 14.6042, 120.9822 14.6042, 120.9822 14.5942, 120.9722 14.5942))', 4326)),
('Location 3', ST_GeomFromText('POLYGON((120.9622 14.5842, 120.9622 14.5942, 120.9722 14.5942, 120.9722 14.5842, 120.9622 14.5842))', 4326)),
('Location 4', ST_GeomFromText('POLYGON((120.9522 14.5742, 120.9522 14.5842, 120.9622 14.5842, 120.9622 14.5742, 120.9522 14.5742))', 4326)),
('Location 5', ST_GeomFromText('POLYGON((120.9422 14.5642, 120.9422 14.5742, 120.9522 14.5742, 120.9522 14.5642, 120.9422 14.5642))', 4326)),
('Location 6', ST_GeomFromText('POLYGON((120.9322 14.5542, 120.9322 14.5642, 120.9422 14.5642, 120.9422 14.5542, 120.9322 14.5542))', 4326)),
('Location 7', ST_GeomFromText('POLYGON((120.9222 14.5442, 120.9222 14.5542, 120.9322 14.5542, 120.9322 14.5442, 120.9222 14.5442))', 4326)),
('Location 8', ST_GeomFromText('POLYGON((120.9122 14.5342, 120.9122 14.5442, 120.9222 14.5442, 120.9222 14.5342, 120.9122 14.5342))', 4326)),
('Location 9', ST_GeomFromText('POLYGON((120.9022 14.5242, 120.9022 14.5342, 120.9122 14.5342, 120.9122 14.5242, 120.9022 14.5242))', 4326)),
('Location 10', ST_GeomFromText('POLYGON((120.8922 14.5142, 120.8922 14.5242, 120.9022 14.5242, 120.9022 14.5142, 120.8922 14.5142))', 4326));

CREATE TABLE movements (
    movementId SERIAL PRIMARY KEY,
    plateNumber VARCHAR(10),
    createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    coordinates GEOMETRY(POINT, 4326),
    FOREIGN KEY (plateNumber) REFERENCES vehicles(plateNumber)
);

WITH vehicleData AS (
    SELECT plateNumber
    FROM vehicles
),
locationData AS (
    SELECT locationId, coordinates
    FROM locations
    LIMIT 10
),
movementIntervals AS (
    SELECT generate_series(1, 30) * interval '10 minutes' AS interval
),
startEndLocations AS (
    SELECT
        v.plateNumber AS plateNumber,
        ld1.coordinates AS startPolygon,
        ld2.coordinates AS endPolygon,
        mi.interval
    FROM vehicleData v
    CROSS JOIN LATERAL (
        SELECT coordinates FROM locationData ld1
        ORDER BY random()
        LIMIT 1
    ) AS ld1
    CROSS JOIN LATERAL (
        SELECT coordinates FROM locationData ld2
        ORDER BY random()
        LIMIT 1
    ) AS ld2
    CROSS JOIN movementIntervals mi
    WHERE ST_Distance(ST_Centroid(ld1.coordinates), ST_Centroid(ld2.coordinates)) > 0  -- Ensure start and end locations are different
),
movementPoints AS (
    SELECT
        plateNumber,
        NOW() - interval '5 days' + interval AS createdAt,
        ST_SetSRID(
            ST_MakePoint(
                -- Random points within the start polygon
                ST_X(ST_Centroid(startPolygon)) + (ST_X(ST_Centroid(endPolygon)) - ST_X(ST_Centroid(startPolygon))) * EXTRACT(EPOCH FROM interval) / (30 * 600),
                ST_Y(ST_Centroid(startPolygon)) + (ST_Y(ST_Centroid(endPolygon)) - ST_Y(ST_Centroid(startPolygon))) * EXTRACT(EPOCH FROM interval) / (30 * 600)
            ),
            4326
        ) AS coordinates
    FROM startEndLocations
)
INSERT INTO movements (plateNumber, createdAt, coordinates)
SELECT plateNumber, createdAt, coordinates
FROM movementPoints
WHERE EXTRACT(EPOCH FROM createdAt - NOW() + interval '5 days') BETWEEN 0 AND 300 * 600;
