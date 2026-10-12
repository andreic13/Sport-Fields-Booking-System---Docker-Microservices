CREATE DATABASE keycloak_db;

-- User profiles table

CREATE TABLE IF NOT EXISTS user_profiles (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255),
    role VARCHAR(50)
);


INSERT INTO user_profiles (username, email, role)
VALUES 
    ('andrei', 'andrei@scd.com', 'user'),
    ('andreiadmin', 'andreiadmin@scd.com', 'admin');

-- Fields table

CREATE TABLE IF NOT EXISTS fields (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    location VARCHAR(255) NOT NULL,
    sport VARCHAR(50) NOT NULL,
    price_per_hour NUMERIC(10,2) NOT NULL
);

INSERT INTO fields (name, location, sport, price_per_hour) VALUES
    ('Teren Academia Germană', 'București, Regie', 'Fotbal', 350),
    ('Dax Tennis Club', 'București, Plaza', 'Tenis', 70),
    ('Teren Politehnica București', 'București, Politehnica', 'Fotbal', 250),
    ('Teren Stejarii', 'București, Stejarii', 'Baschet', 200),
    ('Tennis Club Herăstrău', 'București, Herăstrău', 'Tenis', 90),
    ('Teren Dinamo', 'București, Dinamo', 'Fotbal', 300),
    ('Teren Floreasca', 'București, Floreasca', 'Padel', 150);

CREATE TABLE IF NOT EXISTS bookings (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    field_id INT NOT NULL,
    date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    CONSTRAINT fk_booking_user
        FOREIGN KEY(user_id) REFERENCES user_profiles(id),
    CONSTRAINT fk_booking_field
        FOREIGN KEY(field_id) REFERENCES fields(id)
);

-- 15 exemple pt user 1 si 2
INSERT INTO bookings (user_id, field_id, date, start_time, end_time, status) VALUES
    (1, 1, '2026-01-01', '10:00', '11:00', 'expired'),
    (2, 3, '2026-01-02', '14:00', '15:30', 'expired'),
    (1, 2, '2026-01-03', '09:00', '10:00', 'expired'),
    (1, 5, '2026-01-04', '16:00', '17:00', 'expired'),
    (2, 4, '2026-01-05', '18:00', '19:30', 'expired'),
    (1, 6, '2026-01-06', '12:00', '13:00', 'expired'),
    (1, 7, '2026-01-07', '15:00', '16:00', 'expired'),
    (2, 1, '2026-01-08', '11:00', '12:00', 'cancelled'),
    (1, 3, '2026-01-09', '13:00', '14:30', 'expired'),
    (2, 2, '2026-01-10', '10:00', '11:00', 'expired'),
    (1, 4, '2026-01-11', '17:00', '18:00', 'expired'),
    (2, 5, '2026-01-12', '09:00', '10:30', 'expired'),
    (1, 6, '2026-01-13', '14:00', '15:00', 'expired'),
    (2, 7, '2026-01-14', '16:00', '17:00', 'expired'),
    (1, 1, '2026-01-15', '12:00', '13:00', 'expired'),
    (1, 2, '2026-01-22', '10:00', '11:00', 'active'),
    (2, 3, '2026-01-23', '14:00', '15:30', 'active'),
    (1, 4, '2026-01-24', '09:00', '10:00', 'cancelled'),
    (2, 5, '2026-01-25', '16:00', '17:00', 'active'),
    (1, 6, '2026-01-26', '18:00', '19:30', 'active');