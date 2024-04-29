# MySQL credentials
USER="MYSQL_READONLY_ID"
PASSWORD="MYSQL_READONLY_PASSWORD"
BASE_OUTPUT="/home/backup/mysql"

# Current date for folder naming
DATE=$(date +%Y%m%d)
OUTPUT="$BASE_OUTPUT/$DATE"

# Cloudflare R2 Bucket Name
R2_BUCKET="mcpanel-irochi-moe/mysql"

# Ensure output directory exists
if [ ! -d "$OUTPUT" ]; then
    echo "Output directory $OUTPUT does not exist. Creating..."
    mkdir -p $OUTPUT
    if [ $? -ne 0 ]; then
        echo "Failed to create output directory. Check permissions."
        exit 1
    fi
fi

# Deleting directories older than 10 days in the base output directory
find $BASE_OUTPUT -maxdepth 1 -type d -mtime +7 -exec rm -rf {} \;

# Get a list of databases, excluding specific system databases
databases=$(mysql -u $USER -p$PASSWORD -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql|sys)")

# Backup each database and upload to Cloudflare R2
for db in $databases; do
    echo "Dumping database: $db"
    FILENAME=$db.sql
    mysqldump -u $USER -p$PASSWORD --single-transaction --databases $db > $OUTPUT/$FILENAME

    if [ $? -ne 0 ]; then
        echo "Failed to dump database $db."
        continue
    fi

    echo "Uploading $FILENAME to Cloudflare R2"
    rclone copy $OUTPUT/$FILENAME r2:$R2_BUCKET/$DATE
done
