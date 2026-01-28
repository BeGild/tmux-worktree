#!/usr/bin/env node
import { getAiToolsInfo } from './lib/config.js';

const info = getAiToolsInfo();
console.log(JSON.stringify(info, null, 2));
