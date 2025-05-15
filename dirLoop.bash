#!/bin/bash

currentDir=$(pwd)
for dir in /spec/Syrinx.ApiBranch*; do
  echo "$dir"
  cd "$dir" && git --no-pager log --oneline --decorate --graph -n 4;
done

cd "$currentDir" || exit

