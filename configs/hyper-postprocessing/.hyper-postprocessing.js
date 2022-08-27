const { readFileSync } = require('fs');
const { resolve } = require('path');
const pp = require('postprocessing');
const retro = require('./effects/retro');

module.exports = ({ hyperTerm, xTerm }) => { return retro({hyperTerm, xTerm}); };
