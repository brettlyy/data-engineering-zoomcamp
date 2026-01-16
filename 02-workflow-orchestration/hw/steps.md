# Steps taken for Module 2 Homework

The first bit says the task is to extend the flows to include data for the year 2021. We should be able to just do this with a backfill on our existing flow.

## Quiz Questions

1. Within the execution for Yellow Taxi data for the year 2020 and month 12: what is the uncompressed file size (i.e. the output file yellow_tripdata_2020-12.csv of the extract task)?

    - Run for yellow, 2020, 12 and explore the logs of the extract task

    ![alt text](<Screenshot 2026-01-15 at 10.46.18 PM.png>)

    - Seeing the output file, but not where it says the filesize.
    - Need to come back to this one or just download it and look?

    - Update: tried removing the purge files task to see if that changed anything. It did!
    - Answer: `128.3MiB`

2. What is the rendered value of the variable file when the inputs taxi is set to green, year is set to 2020, and month is set to 04 during execution?

    - Can just tell based on our variable setup
    - Didn't run for this, but can confirm looking at the yellow taxi run and seeing it's in the same structure
    - Answer: `green_tripdata_2020-04.csv`

3. How many rows are there for the Yellow Taxi data for all CSV files in the year 2020?

    - I guess for this I need to backfill all of 2020?
    - Actually I already ran 12-2020 for #1 so just Jan-Nov
    ![alt text](<Screenshot 2026-01-15 at 11.07.24 PM.png>)

    - SQL: `SELECT COUNT(*) FROM public.yellow_tripdata;`
    - Answer: `24,648,499`

4. How many rows are there for the Green Taxi data for all CSV files in the year 2020?

    - Backfill all of 2020
    ![alt text](<Screenshot 2026-01-15 at 11.03.29 PM.png>)

    - SQL: `SELECT COUNT(*) FROM public.green_tripdata;`
    - Answer: `1,734,051`

5. How many rows are there for the Yellow Taxi data for the March 2021 CSV file?

    - Can query, but could probably also just look at Kestra execution
    - Add `allowCustomValue: true` to the year variable or use backfill
    - Answer: `1,925,152`

6. How would you configure the timezone to New York in a Schedule trigger?

    - Look at the docs for scheduling
    - There is a `timezone` property that defaults to Etc/UTC
    - So this makes me thing we just need to set it to EST, and the docs say to use this [wikipedia table](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List)
    - Answer: `timezone: America/New_York` under the schedule trigger
