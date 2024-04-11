create or replace procedure Export(tableName varchar, filePath varchar, delimiter varchar)
as $$
  begin
    execute format('copy %s TO ''%s'' DELIMITER ''%s'' tsv HEADER;',
    tableName, filePath, delimiter);
  end;
$$ language plpgsql;

create EXTENSION if not exists pgcrypto;

call Export('GroupSKU', '/opt/goinfre/jerlenem/SQL_Analitycs/datasets/SKU_group.tsv', '	');
call Export('PersonalInformation', '/opt/goinfre/jerlenem/SQL_Analitycs/datasets/Personal_information.tsv', '	');
call Export('CommodityMatrix', '/opt/goinfre/jerlenem/SQL_Analitycs/datasets/Product_grid.tsv', '	');
call Export('cards', '/opt/goinfre/jerlenem/SQL_Analitycs/datasets/Cards.tsv', '	');
call Export('RetailOutlets', '/opt/goinfre/jerlenem/SQL_Analitycs/datasets/Stores.tsv', '	');
call Export('Transactions', '/opt/goinfre/jerlenem/SQL_Analitycs/datasets/Transactions.tsv', '	');
call Export('AnalysisDate', '/opt/goinfre/jerlenem/SQL_Analitycs/datasets/Date_Of_Analysis_Formation.tsv', '	');
call Export('Checks', '/opt/goinfre/jerlenem/SQL_Analitycs/datasets/Checks.tsv', '	');