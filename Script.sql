-- create foreign data wrapper
create foreign data wrapper prometheus_wrapper
  handler prometheus_fdw_handler
  validator prometheus_fdw_validator;

-- create server by providing location of prometheus
create server my_prometheus_server
  foreign data wrapper prometheus_wrapper
  options (
    base_url 'http://localhost:9090/');

-- create foreign table by providing the interval of data that you expect   
CREATE FOREIGN TABLE IF NOT EXISTS metrics (
  metric_name TEXT,
  metric_labels JSONB,
  metric_time BIGINT, 
  metric_value FLOAT8
  ) 
server my_prometheus_server
options (
  object 'metrics',
  step '1m'
);   

--create local metrics table
CREATE TABLE IF NOT EXISTS metrics_local (
  metric_name TEXT,
  metric_labels JSONB,
  metric_time BIGINT, 
  metric_value FLOAT8
);

CREATE TABLE job (
	job_id BIGSERIAL,
	job_name text NULL,
	job_control_time timestamp NULL
);
insert into job values (default,'prometheus_fdw', date_trunc('minute',current_timestamp- interval '3 minutes')::timestamp );

--create function to load metrics data into local postgres metrics table 
CREATE OR REPLACE FUNCTION insert_metrics() RETURNS void LANGUAGE plpgsql AS $$
Declare
    start_time_in_epoch BIGINT := (select EXTRACT(epoch FROM job_control_time - interval '1 minute' )::BIGINT 
   						from job where job_name = 'prometheus_fdw');
    end_time_in_epoch BIGINT := EXTRACT(epoch FROM now())::BIGINT;

begin
    EXECUTE format(
        'INSERT INTO metrics_local
        SELECT * FROM metrics
        WHERE
          metric_name = ''container_cpu_usage_seconds_total''
          AND metric_time > %s 
          AND metric_time < %s ' ,
        start_time_in_epoch,
        end_time_in_epoch
    );   
   update job set job_control_time = to_timestamp(end_time_in_epoch)::timestamp where job_name = 'prometheus_fdw';
end $$;

select * from metrics_local order by 2,3;

-- cron job to sync changes from prometheus 
SELECT cron.schedule('*/3 * * * *',
    $$
    select insert_metrics();
    $$
);

-- you should be seeing the metrics data ordered by 1 minute intervals
select * from metrics_local order by 2,3;


select * from cron.job_run_details order by start_time desc ;
select * from cron.job;
select cron.unschedule(4);
SELECT * FROM pg_available_extensions;
SELECT * FROM metrics 
WHERE 
  metric_name='container_cpu_usage_seconds_total' 
  AND metric_time > 1704778740 AND metric_time < 1704778900
 order by 3 ;

