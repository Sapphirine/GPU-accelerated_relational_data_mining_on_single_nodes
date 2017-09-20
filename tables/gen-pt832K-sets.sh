mkdir -p pt832K-join-sets
cd pt832K-join-sets
cp ../pt832K.csv .
cp pt832K.csv pt208K.csv
cp pt832K.csv pt416K.csv
cp pt832K.csv pt2M.csv
cp pt832K.csv pt3M.csv
cp pt832K.csv pt7M.csv
cp pt832K.csv pt10M.csv
cp pt832K.csv pt13M.csv
cp pt832K.csv pt16M.csv

cp ../lpt208K.csv ../lpt416K.csv ../lpt832K.csv .
cat lpt832K.csv > lpt2M.csv
cat lpt832K.csv >> lpt2M.csv
cat lpt2M.csv > lpt3M.csv
cat lpt2M.csv >> lpt3M.csv
cat lpt3M.csv > lpt7M.csv
cat lpt3M.csv >> lpt7M.csv
cat lpt7M.csv > lpt10M.csv
cat lpt3M.csv >> lpt10M.csv
cat lpt7M.csv > lpt13M.csv
cat lpt7M.csv >> lpt13M.csv
cat lpt13M.csv > lpt16M.csv
cat lpt3M.csv >> lpt16M.csv

cp ../rt208K.csv ../rt416K.csv ../rt832K.csv .
cat rt832K.csv > rt2M.csv
cat rt832K.csv >> rt2M.csv
cat rt2M.csv > rt3M.csv
cat rt2M.csv >> rt3M.csv
cat rt3M.csv > rt7M.csv
cat rt3M.csv >> rt7M.csv
cat rt7M.csv > rt10M.csv
cat rt3M.csv >> rt10M.csv
cat rt7M.csv > rt13M.csv
cat rt7M.csv >> rt13M.csv
cat rt13M.csv > rt16M.csv
cat rt3M.csv >> rt16M.csv

