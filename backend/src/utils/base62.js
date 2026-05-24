const CHARS = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
const BASE = BigInt(CHARS.length);

function encode(num) {
  if (typeof num === 'bigint' && num === 0n) return CHARS[0];
  if (num === 0) return CHARS[0];
  let n = typeof num === 'bigint' ? num : BigInt(num);
  let result = '';
  while (n > 0n) {
    result = CHARS[Number(n % BASE)] + result;
    n = n / BASE;
  }
  return result;
}

function decode(str) {
  let result = 0n;
  for (const char of str) {
    result = result * BASE + BigInt(CHARS.indexOf(char));
  }
  return Number(result);
}

module.exports = { encode, decode };