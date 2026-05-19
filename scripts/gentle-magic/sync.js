const { markdownMagic } = require('markdown-magic')
const path = require('path')
const fs = require('fs')

const MASTER_DIR = path.join(process.env.HOME, '.gentle-ai/shared')
const BACKENDS = {
  opencode: path.join(process.env.HOME, '.config/opencode/AGENTS.md'),
  claude: path.join(process.env.HOME, '.claude/CLAUDE.md'),
  gemini: path.join(process.env.HOME, '.gemini/GEMINI.md')
}

// Transformación personalizada para extraer bloques específicos
const config = {
  transforms: {
    GENTLE_BLOCK: (content, options) => {
      if (!options) return content
      const { src, block } = options

      const sourceKey = src.toLowerCase()
      const sourcePath = BACKENDS[sourceKey]
      
      if (!sourcePath || !fs.existsSync(sourcePath)) {
        return `<!-- Source ${src} not found at ${sourcePath} -->`
      }

      const fileContent = fs.readFileSync(sourcePath, 'utf8')
      const startTag = `<!-- gentle-ai:${block} -->`
      const endTag = `<!-- /gentle-ai:${block} -->`
      
      const startIndex = fileContent.indexOf(startTag)
      const endIndex = fileContent.indexOf(endTag)
      
      if (startIndex === -1 || endIndex === -1) {
        return `<!-- Block ${block} not found in ${src} -->`
      }
      
      // Extraer el contenido entre las etiquetas
      const extracted = fileContent.substring(startIndex + startTag.length, endIndex).trim()
      return `\n${extracted}\n`
    }
  },
  callback: function () {
    console.log('✨ Merge de secciones completado.')
  }
}

const masterPath = path.join(MASTER_DIR, 'AGENTS.md')

// 1. Crear el Master si no existe (usaremos el de Gemini como semilla si es necesario)
if (!fs.existsSync(masterPath)) {
  console.log('📝 Creando Master AGENTS.md inicial...')
  const seed = fs.existsSync(BACKENDS.gemini) ? fs.readFileSync(BACKENDS.gemini, 'utf8') : '# AGENTS Master\n'
  fs.writeFileSync(masterPath, seed)
}

console.log('🚀 Ejecutando sincronización quirúrgica...')

markdownMagic(masterPath, config, () => {
  // 2. Distribuir a los backends
  const ununifiedContent = fs.readFileSync(masterPath, 'utf8')
  
  Object.entries(BACKENDS).forEach(([key, destPath]) => {
    const dir = path.dirname(destPath)
    if (fs.existsSync(dir)) {
      fs.writeFileSync(destPath, ununifiedContent)
      console.log(`   ✅ Sincronizado ${key}: ${destPath}`)
    }
  })
})
