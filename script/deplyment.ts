import * as fs from 'fs';
import * as path from 'path';

let network = 'sepolia';
for (let i = 2; i < process.argv.length; i++) {
  if (process.argv[i] === '--network' || process.argv[i] === '-n') {
    if (i + 1 < process.argv.length) {
      network = process.argv[i + 1];
      break;
    }
  } else if (process.argv[i].startsWith('--network=')) {
    network = process.argv[i].split('=')[1];
    break;
  } else if (process.argv[i].startsWith('-n=')) {
    network = process.argv[i].split('=')[1];
    break;
  }
}


function findLatestRunJson(dir: string): string {
  let result: string | null = null;
  function search(currentDir: string) {
    const files = fs.readdirSync(currentDir);
    for (const file of files) {
      const fullPath = path.join(currentDir, file);
      const stat = fs.statSync(fullPath);
      if (stat.isDirectory()) {
        search(fullPath);
      } else if (file === 'run-latest.json') {
        if (
          result === null ||
          fs.statSync(fullPath).mtimeMs > fs.statSync(result).mtimeMs
        ) {
          result = fullPath;
        }
      }
    }
  }

  search(dir);

  if (!result) {
    throw new Error('run-latest.json not found');
  }
  return result;
}
const broadcastDir = path.join(__dirname, '../broadcast');
const inputPath = findLatestRunJson(broadcastDir);
const outputPath = path.join(__dirname, `../deployment/${network}.json`);

const outputDir = path.dirname(outputPath);
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}


const rawData = fs.readFileSync(inputPath, 'utf-8');
const jsonData = JSON.parse(rawData);

let transactions: any[] = [];
if (Array.isArray(jsonData.transactions)) {
  transactions = jsonData.transactions;
} else if (Array.isArray(jsonData)) {
  transactions = jsonData;
} else {
  throw new Error('transactions not found');
}

const createTxs = transactions.filter(tx => tx.transactionType === 'CREATE' && tx.contractName !== 'TransparentUpgradeableProxy').map(tx => {
  return {
    contract: tx.contractName,
    address: tx.contractAddress
  }
});


transactions
  .filter(
    tx =>
      tx.transactionType === 'CREATE' &&
      tx.contractName === 'TransparentUpgradeableProxy'
  )
  .forEach(tx => {
    if (
      Array.isArray(tx.arguments) &&
      tx.arguments.length > 0 &&
      typeof tx.arguments[0] === 'string'
    ) {
      const target = createTxs.find(
        (v) => {
          return v.address.toLowerCase() === tx.arguments[0].toLowerCase()
        }
      );
      if (target) {
        target.address = tx.contractAddress;
        // @ts-ignore
        target.proxyAdmin = tx.additionalContracts[0].address;
      }
    }
  });


createTxs.reduce((acc, tx) => {
  acc[tx.contract] = tx.address;
  return acc;
}, {});

fs.writeFileSync(outputPath, JSON.stringify(createTxs, null, 2), 'utf-8');

console.log(`${network}.json updated`);
