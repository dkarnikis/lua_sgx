for file in $(find . -name '*.cpp')
do
  mv $file $(echo "$file" | sed -r 's|.cpp|.c|g')
done
