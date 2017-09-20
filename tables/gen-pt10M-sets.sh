mkdir -p pt10M-sets
cd pt10M-sets
cp ../pt10M.csv .
cp pt10M.csv pt208K.csv
cp pt10M.csv pt416K.csv
cp pt10M.csv pt832K.csv
cp pt10M.csv pt2M.csv
cp pt10M.csv pt3M.csv
cp pt10M.csv pt7M.csv
cp pt10M.csv pt13M.csv
cp pt10M.csv pt16M.csv

cp ../lpt208K.csv ../lpt416K.csv ../lpt832K.csv .
cp ../lpt2M.csv ../lpt3M.csv ../lpt7M.csv ../lpt10M.csv .
cat lpt10M.csv > lpt13M.csv
cat lpt3M.csv >> lpt13M.csv
cat lpt13M.csv > lpt16M.csv
cat lpt3M.csv >> lpt16M.csv

cp ../rt208K.csv ../rt416K.csv ../rt832K.csv .
cp ../rt2M.csv ../rt3M.csv ../rt7M.csv ../rt10M.csv .
cat rt10M.csv > rt13M.csv
cat rt3M.csv >> rt13M.csv
cat rt13M.csv > rt16M.csv
cat rt3M.csv >> rt16M.csv
