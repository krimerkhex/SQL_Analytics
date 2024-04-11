    -- создание Админа
    CREATE ROLE administrator;
    GRANT ALL PRIVILEGES ON DATABASE postgres TO administrator;
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO administrator;
    GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO administrator;

    -- создание поль. для просмотра
    CREATE ROLE visitor;
    GRANT SELECT ON ALL TABLES IN SCHEMA public TO visitor;

    -- присвоение роли для пользователя
    GRANT administrator TO postgres;
    GRANT visitor TO postgres;