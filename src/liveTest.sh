#!/usr/bin/env bash
cd "${0%/*}"
npx buidler test tests_live/live.test.js --network localhost