import pandas as pd
import pyarrow.dataset as ds
from sqlalchemy import create_engine
from tqdm.auto import tqdm

user = "postgres"
password = "postgres"
host = "postgres"
port = 5432
db = "ny_taxi"
chunksize = 10_000

def ingest_trips_data(user, password, host, port, db, table, year, month, chunksize):

    prefix = 'https://d37ci6vzurychx.cloudfront.net/trip-data'
    url = f'{prefix}/green_tripdata_{year}-{month:02d}.parquet'

    engine = create_engine(f'postgresql://{user}:{password}@{host}:{port}/{db}')

    df = pd.read_parquet(url)

    first = True
    for start in tqdm(range(0, len(df), chunksize), desc="Batches"):
        batch = df.iloc[start:start + chunksize]
        if first:
            batch.head(0).to_sql(
                name=table,
                con=engine,
                if_exists="replace",
                index=False
            )
            first = False

        batch.to_sql(
            name=table,
            con=engine,
            if_exists="append",
            index=False,
            chunksize=chunksize
        )

    print('Loaded trips data')

def ingest_zones_lookup(user, password, host, port, db, table):
    
    url = 'https://github.com/DataTalksClub/nyc-tlc-data/releases/download/misc/taxi_zone_lookup.csv'

    engine = create_engine(f'postgresql://{user}:{password}@{host}:{port}/{db}')

    df = pd.read_csv(url)

    df.to_sql(
        name=table,
        con=engine,
        if_exists="replace"
    )

    print('Loaded zones data')

if __name__ == '__main__':
    ingest_trips_data(user=user, password=password, host=host, port=port, db=db, table='green_taxi_trips', year=2025, month=11, chunksize=chunksize)
    ingest_zones_lookup(user=user, password=password, host=host, port=port, db=db, table='zones_lookup')