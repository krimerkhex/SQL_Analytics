create or replace procedure ImportDataFromCsv(
    tableName varchar,
    filePath varchar,
    delimiter varchar)
as $$
  begin
    execute format('COPY %s FROM ''%s'' DELIMITER ''%s'' CSV HEADER;',
    tableName, filePath, delimiter);
  end;
$$ language plpgsql;

CREATE OR REPLACE PROCEDURE ImportDataFromTsv(
    table_name VARCHAR,
    file_path VARCHAR,
    delimiter VARCHAR
)
LANGUAGE plpgsql
AS
    $$
BEGIN
    IF table_name = 'Transactions' OR table_name = 'AnalysisDate' THEN
        EXECUTE FORMAT('SET DATESTYLE TO DMY; COPY %s FROM ''%s'' DELIMITER ''%s'' CSV HEADER', table_name, file_path, delimiter);
    else
        execute format('COPY %s FROM ''%s'' DELIMITER ''%s'' CSV HEADER;', table_name, file_path, delimiter);
    END IF;
END;
$$;
call ImportDataFromTsv('GroupSKU', 'C:\Doing_somethings\School_21\SQL3_RetailAnalitycs_v1.0-1\datasets\Groups_SKU_Mini.tsv', '	');
call ImportDataFromTsv('PersonalInformation', 'C:\Doing_somethings\School_21\SQL3_RetailAnalitycs_v1.0-1\datasets\Personal_Data_Mini.tsv', '	');
call ImportDataFromTsv('CommodityMatrix', 'C:\Doing_somethings\School_21\SQL3_RetailAnalitycs_v1.0-1\datasets\SKU_Mini.tsv', '	');
call ImportDataFromTsv('Cards', 'C:\Doing_somethings\School_21\SQL3_RetailAnalitycs_v1.0-1\datasets\Cards_Mini.tsv', '	');
call ImportDataFromTsv('RetailOutlets', 'C:\Doing_somethings\School_21\SQL3_RetailAnalitycs_v1.0-1\datasets\Stores_Mini.tsv', '	');
call ImportDataFromTsv('AnalysisDate', 'C:\Doing_somethings\School_21\SQL3_RetailAnalitycs_v1.0-1\datasets\Date_Of_Analysis_Formation.tsv', '	');
call ImportDataFromTsv('Transactions', 'C:\Doing_somethings\School_21\SQL3_RetailAnalitycs_v1.0-1\datasets\Transactions_Mini.tsv', '	');
call ImportDataFromTsv('Checks', 'C:\Doing_somethings\School_21\SQL3_RetailAnalitycs_v1.0-1\datasets\Checks_Mini.tsv', '	');


