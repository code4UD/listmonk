<template>
  <section class="mairies-import">
    <header class="columns">
      <div class="column is-half">
        <h1 class="title is-4">{{ $t('mairies.import.title') }}</h1>
        <p class="has-text-grey">{{ $t('mairies.import.description') }}</p>
      </div>
      <div class="column has-text-right">
        <b-button
          @click="downloadTemplate"
          icon-left="download"
          type="is-primary"
          :loading="downloading"
        >
          {{ $t('mairies.import.downloadTemplate') }}
        </b-button>
      </div>
    </header>

    <hr />

    <div class="columns">
      <div class="column is-8">
        <div class="box">
          <h2 class="title is-5">{{ $t('mairies.import.uploadFile') }}</h2>
          
          <b-field>
            <b-upload
              v-model="csvFile"
              @input="onFileSelect"
              drag-drop
              accept=".csv"
              :loading="uploading"
            >
              <section class="section">
                <div class="content has-text-centered">
                  <p>
                    <b-icon icon="upload" size="is-large"></b-icon>
                  </p>
                  <p>{{ $t('mairies.import.dragDrop') }}</p>
                  <p class="has-text-grey">{{ $t('mairies.import.csvOnly') }}</p>
                </div>
              </section>
            </b-upload>
          </b-field>

          <div v-if="csvFile" class="notification is-info">
            <p><strong>{{ $t('mairies.import.selectedFile') }}:</strong> {{ csvFile.name }}</p>
            <p><strong>{{ $t('mairies.import.fileSize') }}:</strong> {{ formatFileSize(csvFile.size) }}</p>
          </div>

          <div v-if="validationResult" class="notification" :class="validationResult.valid ? 'is-success' : 'is-warning'">
            <h4 class="title is-6">{{ $t('mairies.import.validationResult') }}</h4>
            <p><strong>{{ $t('mairies.import.totalRows') }}:</strong> {{ validationResult.totalRows }}</p>
            <p><strong>{{ $t('mairies.import.validRows') }}:</strong> {{ validationResult.validRows }}</p>
            <p v-if="validationResult.errors.length > 0">
              <strong>{{ $t('mairies.import.errors') }}:</strong>
            </p>
            <ul v-if="validationResult.errors.length > 0">
              <li v-for="error in validationResult.errors.slice(0, 5)" :key="error">{{ error }}</li>
              <li v-if="validationResult.errors.length > 5">
                {{ $t('mairies.import.moreErrors', { count: validationResult.errors.length - 5 }) }}
              </li>
            </ul>
          </div>

          <div class="field is-grouped" v-if="csvFile">
            <div class="control">
              <b-button
                @click="validateFile"
                type="is-info"
                :loading="validating"
                icon-left="check-circle"
              >
                {{ $t('mairies.import.validate') }}
              </b-button>
            </div>
            <div class="control">
              <b-button
                @click="importFile"
                type="is-success"
                :loading="importing"
                :disabled="!validationResult || !validationResult.valid"
                icon-left="upload"
              >
                {{ $t('mairies.import.import') }}
              </b-button>
            </div>
          </div>
        </div>
      </div>

      <div class="column is-4">
        <div class="box">
          <h3 class="title is-6">{{ $t('mairies.import.requirements') }}</h3>
          <div class="content">
            <p>{{ $t('mairies.import.csvFormat') }}</p>
            <ul>
              <li>nom_commune</li>
              <li>code_insee</li>
              <li>code_departement</li>
              <li>population</li>
              <li>email</li>
              <li>nom_contact</li>
              <li>code_postal</li>
              <li>latitude</li>
              <li>longitude</li>
            </ul>
          </div>
        </div>

        <div class="box" v-if="importStats">
          <h3 class="title is-6">{{ $t('mairies.import.lastImport') }}</h3>
          <div class="content">
            <p><strong>{{ $t('mairies.import.date') }}:</strong> {{ formatDate(importStats.date) }}</p>
            <p><strong>{{ $t('mairies.import.imported') }}:</strong> {{ importStats.imported }}</p>
            <p><strong>{{ $t('mairies.import.updated') }}:</strong> {{ importStats.updated }}</p>
            <p><strong>{{ $t('mairies.import.errors') }}:</strong> {{ importStats.errors }}</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Import Progress Modal -->
    <b-modal v-model="showProgress" :can-cancel="false" has-modal-card>
      <div class="modal-card">
        <header class="modal-card-head">
          <p class="modal-card-title">{{ $t('mairies.import.importing') }}</p>
        </header>
        <section class="modal-card-body">
          <div class="content">
            <p>{{ $t('mairies.import.importProgress') }}</p>
            <b-progress
              :value="importProgress"
              :max="100"
              type="is-primary"
              show-value
            ></b-progress>
            <p v-if="importStatus" class="has-text-grey">{{ importStatus }}</p>
          </div>
        </section>
      </div>
    </b-modal>
  </section>
</template>

<script>
import { mapState } from 'vuex'

export default {
  name: 'MairiesImport',
  
  data() {
    return {
      csvFile: null,
      validationResult: null,
      importStats: null,
      downloading: false,
      uploading: false,
      validating: false,
      importing: false,
      showProgress: false,
      importProgress: 0,
      importStatus: ''
    }
  },

  computed: {
    ...mapState(['loading'])
  },

  mounted() {
    this.getImportStats()
  },

  methods: {
    async downloadTemplate() {
      this.downloading = true
      try {
        const response = await this.$api.getCSVTemplate()
        const blob = new Blob([response.data], { type: 'text/csv' })
        const url = window.URL.createObjectURL(blob)
        const link = document.createElement('a')
        link.href = url
        link.download = 'mairies-template.csv'
        link.click()
        window.URL.revokeObjectURL(url)
      } catch (e) {
        this.$buefy.toast.open({
          message: this.$t('mairies.import.downloadError'),
          type: 'is-danger'
        })
      } finally {
        this.downloading = false
      }
    },

    onFileSelect() {
      this.validationResult = null
    },

    async validateFile() {
      if (!this.csvFile) return

      this.validating = true
      try {
        const formData = new FormData()
        formData.append('file', this.csvFile)
        
        const response = await this.$api.validateCSV(formData)
        this.validationResult = response.data
        
        if (this.validationResult.valid) {
          this.$buefy.toast.open({
            message: this.$t('mairies.import.validationSuccess'),
            type: 'is-success'
          })
        } else {
          this.$buefy.toast.open({
            message: this.$t('mairies.import.validationWarning'),
            type: 'is-warning'
          })
        }
      } catch (e) {
        this.$buefy.toast.open({
          message: this.$t('mairies.import.validationError'),
          type: 'is-danger'
        })
      } finally {
        this.validating = false
      }
    },

    async importFile() {
      if (!this.csvFile || !this.validationResult?.valid) return

      this.importing = true
      this.showProgress = true
      this.importProgress = 0
      this.importStatus = this.$t('mairies.import.starting')

      try {
        const formData = new FormData()
        formData.append('file', this.csvFile)
        
        // Simulate progress updates
        const progressInterval = setInterval(() => {
          if (this.importProgress < 90) {
            this.importProgress += Math.random() * 10
            this.importStatus = this.$t('mairies.import.processing', { 
              progress: Math.round(this.importProgress) 
            })
          }
        }, 500)

        const response = await this.$api.importMairies(formData)
        
        clearInterval(progressInterval)
        this.importProgress = 100
        this.importStatus = this.$t('mairies.import.completed')
        
        setTimeout(() => {
          this.showProgress = false
          this.importStats = response.data
          this.csvFile = null
          this.validationResult = null
          
          this.$buefy.toast.open({
            message: this.$t('mairies.import.importSuccess', { 
              count: response.data.imported 
            }),
            type: 'is-success',
            duration: 5000
          })
        }, 1000)
        
      } catch (e) {
        this.showProgress = false
        this.$buefy.toast.open({
          message: this.$t('mairies.import.importError'),
          type: 'is-danger'
        })
      } finally {
        this.importing = false
      }
    },

    async getImportStats() {
      try {
        const response = await this.$api.getImportStats()
        this.importStats = response.data
      } catch (e) {
        // Ignore error if no previous import
      }
    },

    formatFileSize(bytes) {
      if (bytes === 0) return '0 Bytes'
      const k = 1024
      const sizes = ['Bytes', 'KB', 'MB', 'GB']
      const i = Math.floor(Math.log(bytes) / Math.log(k))
      return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
    },

    formatDate(dateString) {
      return new Date(dateString).toLocaleString()
    }
  }
}
</script>

<style lang="scss" scoped>
.mairies-import {
  .upload {
    .section {
      padding: 2rem;
      border: 2px dashed #dbdbdb;
      border-radius: 6px;
      transition: border-color 0.3s;
      
      &:hover {
        border-color: #3273dc;
      }
    }
  }
  
  .notification {
    margin-top: 1rem;
  }
}
</style>