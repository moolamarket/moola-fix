module.exports = {
  extends: '../../config/typedoc.js',
  entryPoints: ['src'],
  out: 'docs',
  exclude: [
    'tests/**/**',
    'src/chains/**',
    'src/eips/**',
    'src/hardforks/**'
  ],
}