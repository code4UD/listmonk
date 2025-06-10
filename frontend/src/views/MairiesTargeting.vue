<template>
  <section class="mairies-targeting">
    <header class="columns">
      <div class="column">
        <h1 class="title is-4">{{ $t('mairies.targeting.title') }}</h1>
        <p class="has-text-grey">{{ $t('mairies.targeting.description') }}</p>
      </div>
    </header>

    <hr />

    <div class="columns">
      <!-- Filters Panel -->
      <div class="column is-4">
        <div class="box">
          <h2 class="title is-5">{{ $t('mairies.targeting.filters') }}</h2>

          <!-- Population Filter -->
          <b-field :label="$t('mairies.targeting.population')">
            <div class="field has-addons">
              <div class="control">
                <b-input
                  v-model.number="filters.populationMin"
                  type="number"
                  :placeholder="$t('mairies.targeting.minPopulation')"
                  min="0"
                />
              </div>
              <div class="control">
                <b-button static>-</b-button>
              </div>
              <div class="control">
                <b-input
                  v-model.number="filters.populationMax"
                  type="number"
                  :placeholder="$t('mairies.targeting.maxPopulation')"
                  min="0"
                />
              </div>
            </div>
          </b-field>

          <!-- Quick Population Filters -->
          <b-field grouped multiline>
            <div class="control">
              <b-button
                @click="setPopulationRange(0, 1000)"
                size="is-small"
                :type="isPopulationRangeActive(0, 1000) ? 'is-primary' : ''"
              >
                &lt; 1k
              </b-button>
            </div>
            <div class="control">
              <b-button
                @click="setPopulationRange(1000, 5000)"
                size="is-small"
                :type="isPopulationRangeActive(1000, 5000) ? 'is-primary' : ''"
              >
                1k - 5k
              </b-button>
            </div>
            <div class="control">
              <b-button
                @click="setPopulationRange(5000, 20000)"
                size="is-small"
                :type="isPopulationRangeActive(5000, 20000) ? 'is-primary' : ''"
              >
                5k - 20k
              </b-button>
            </div>
            <div class="control">
              <b-button
                @click="setPopulationRange(20000, null)"
                size="is-small"
                :type="isPopulationRangeActive(20000, null) ? 'is-primary' : ''"
              >
                &gt; 20k
              </b-button>
            </div>
          </b-field>

          <!-- Department Filter -->
          <b-field :label="$t('mairies.targeting.departments')">
            <b-taginput
              v-model="filters.departments"
              :data="availableDepartments"
              autocomplete
              :placeholder="$t('mairies.targeting.selectDepartments')"
              field="name"
              :loading="loadingDepartments"
              @typing="getDepartments"
            >
              <template slot-scope="props">
                {{ props.option.code }} - {{ props.option.name }}
              </template>
            </b-taginput>
          </b-field>

          <!-- Region Quick Filters -->
          <b-field :label="$t('mairies.targeting.regions')" grouped multiline>
            <div class="control" v-for="region in quickRegions" :key="region.code">
              <b-button
                @click="selectRegion(region)"
                size="is-small"
                :type="isRegionSelected(region) ? 'is-info' : ''"
              >
                {{ region.name }}
              </b-button>
            </div>
          </b-field>

          <!-- Actions -->
          <div class="field is-grouped">
            <div class="control">
              <b-button
                @click="applyFilters"
                type="is-primary"
                :loading="searching"
                icon-left="search"
              >
                {{ $t('mairies.targeting.search') }}
              </b-button>
            </div>
            <div class="control">
              <b-button
                @click="clearFilters"
                icon-left="refresh"
              >
                {{ $t('mairies.targeting.clear') }}
              </b-button>
            </div>
          </div>

          <!-- Results Summary -->
          <div v-if="searchResults" class="notification is-info">
            <h4 class="title is-6">{{ $t('mairies.targeting.results') }}</h4>
            <p><strong>{{ searchResults.total }}</strong> {{ $t('mairies.targeting.mairiesFound') }}</p>
            <p v-if="searchResults.totalPopulation">
              <strong>{{ $t('mairies.targeting.totalPopulation') }}:</strong>
              {{ formatNumber(searchResults.totalPopulation) }}
            </p>
          </div>
        </div>
      </div>

      <!-- Map and Results -->
      <div class="column is-8">
        <div class="box">
          <div class="tabs">
            <ul>
              <li :class="{ 'is-active': activeTab === 'map' }">
                <a @click="activeTab = 'map'" @keyup.enter="activeTab = 'map'" tabindex="0">
                  <span class="icon is-small"><i class="fas fa-map" /></span>
                  <span>{{ $t('mairies.targeting.map') }}</span>
                </a>
              </li>
              <li :class="{ 'is-active': activeTab === 'list' }">
                <a @click="activeTab = 'list'" @keyup.enter="activeTab = 'list'" tabindex="0">
                  <span class="icon is-small"><i class="fas fa-list" /></span>
                  <span>{{ $t('mairies.targeting.list') }}</span>
                </a>
              </li>
              <li :class="{ 'is-active': activeTab === 'stats' }">
                <a @click="activeTab = 'stats'" @keyup.enter="activeTab = 'stats'" tabindex="0">
                  <span class="icon is-small"><i class="fas fa-chart-bar" /></span>
                  <span>{{ $t('mairies.targeting.statistics') }}</span>
                </a>
              </li>
            </ul>
          </div>

          <!-- Map Tab -->
          <div v-show="activeTab === 'map'" class="map-container">
            <div v-if="searchResults && searchResults.mairies.length > 0">
              <MairiesMap
                :mairies="searchResults.mairies"
                :height="'500px'"
                :show-clusters="true"
                @marker-click="onMarkerClick"
              />
            </div>
            <div v-else class="map-placeholder">
              <div class="content has-text-centered">
                <p class="title is-5">{{ $t('mairies.targeting.mapPlaceholder') }}</p>
                <p class="has-text-grey">{{ $t('mairies.targeting.mapPlaceholderText') }}</p>
              </div>
            </div>
          </div>

          <!-- List Tab -->
          <div v-show="activeTab === 'list'">
            <div v-if="searchResults && searchResults.mairies.length > 0">
              <div class="level">
                <div class="level-left">
                  <div class="level-item">
                    <p class="subtitle is-6">
                      {{ $t('mairies.targeting.showing') }}
                      {{ Math.min(currentPage * pageSize, searchResults.total) }}
                      {{ $t('mairies.targeting.of') }}
                      {{ searchResults.total }}
                    </p>
                  </div>
                </div>
                <div class="level-right">
                  <div class="level-item">
                    <b-button
                      @click="exportResults"
                      type="is-info"
                      size="is-small"
                      icon-left="download"
                      :loading="exporting"
                    >
                      {{ $t('mairies.targeting.export') }}
                    </b-button>
                  </div>
                </div>
              </div>

              <b-table
                :data="searchResults.mairies"
                :loading="searching"
                paginated
                :per-page="pageSize"
                :current-page.sync="currentPage"
                detailed
                detail-key="id"
                :show-detail-icon="true"
              >
                <b-table-column field="nom_commune" :label="$t('mairies.targeting.commune')" v-slot="props">
                  {{ props.row.nom_commune }}
                </b-table-column>

                <b-table-column field="code_departement" :label="$t('mairies.targeting.department')" v-slot="props">
                  {{ props.row.code_departement }}
                </b-table-column>

                <b-table-column field="population" :label="$t('mairies.targeting.population')" numeric v-slot="props">
                  {{ formatNumber(props.row.population) }}
                </b-table-column>

                <b-table-column field="email" :label="$t('mairies.targeting.email')" v-slot="props">
                  <a :href="`mailto:${props.row.email}`">{{ props.row.email }}</a>
                </b-table-column>

                <template #detail="props">
                  <div class="content">
                    <p><strong>{{ $t('mairies.targeting.contact') }}:</strong> {{ props.row.nom_contact }}</p>
                    <p><strong>{{ $t('mairies.targeting.postalCode') }}:</strong> {{ props.row.code_postal }}</p>
                    <p><strong>{{ $t('mairies.targeting.insee') }}:</strong> {{ props.row.code_insee }}</p>
                    <p>
<strong>{{ $t('mairies.targeting.coordinates') }}:</strong>
                      {{ props.row.latitude }}, {{ props.row.longitude }}
                    </p>
                  </div>
                </template>
              </b-table>
            </div>
            <div v-else-if="searchResults && searchResults.mairies.length === 0" class="content has-text-centered">
              <p class="title is-5">{{ $t('mairies.targeting.noResults') }}</p>
              <p class="has-text-grey">{{ $t('mairies.targeting.noResultsText') }}</p>
            </div>
            <div v-else class="content has-text-centered">
              <p class="title is-5">{{ $t('mairies.targeting.listPlaceholder') }}</p>
              <p class="has-text-grey">{{ $t('mairies.targeting.listPlaceholderText') }}</p>
            </div>
          </div>

          <!-- Statistics Tab -->
          <div v-show="activeTab === 'stats'">
            <div v-if="searchResults && searchResults.statistics">
              <div class="columns">
                <div class="column">
                  <div class="box has-text-centered">
                    <p class="title is-3">{{ searchResults.statistics.byPopulation.small }}</p>
                    <p class="subtitle">{{ $t('mairies.targeting.smallCommunes') }}</p>
                    <p class="has-text-grey">&lt; 1,000 hab.</p>
                  </div>
                </div>
                <div class="column">
                  <div class="box has-text-centered">
                    <p class="title is-3">{{ searchResults.statistics.byPopulation.medium }}</p>
                    <p class="subtitle">{{ $t('mairies.targeting.mediumCommunes') }}</p>
                    <p class="has-text-grey">1,000 - 20,000 hab.</p>
                  </div>
                </div>
                <div class="column">
                  <div class="box has-text-centered">
                    <p class="title is-3">{{ searchResults.statistics.byPopulation.large }}</p>
                    <p class="subtitle">{{ $t('mairies.targeting.largeCommunes') }}</p>
                    <p class="has-text-grey">&gt; 20,000 hab.</p>
                  </div>
                </div>
              </div>

              <div class="box">
                <h3 class="title is-5">{{ $t('mairies.targeting.byDepartment') }}</h3>
                <div class="columns is-multiline">
                  <div
                    v-for="dept in searchResults.statistics.byDepartment"
                    :key="dept.code"
                    class="column is-3"
                  >
                    <div class="content">
                      <p><strong>{{ dept.code }}</strong> - {{ dept.count }} mairies</p>
                      <p class="has-text-grey">{{ formatNumber(dept.totalPopulation) }} hab.</p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
            <div v-else class="content has-text-centered">
              <p class="title is-5">{{ $t('mairies.targeting.statsPlaceholder') }}</p>
              <p class="has-text-grey">{{ $t('mairies.targeting.statsPlaceholderText') }}</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<script>
import MairiesMap from '@/components/MairiesMap.vue';

export default {
  name: 'MairiesTargeting',

  components: {
    MairiesMap,
  },

  data() {
    return {
      activeTab: 'map',
      filters: {
        populationMin: null,
        populationMax: null,
        departments: [],
      },
      availableDepartments: [],
      loadingDepartments: false,
      searchResults: null,
      searching: false,
      exporting: false,
      currentPage: 1,
      pageSize: 20,
      map: null,
      quickRegions: [
        { code: 'idf', name: 'Île-de-France', departments: ['75', '77', '78', '91', '92', '93', '94', '95'] },
        { code: 'paca', name: 'PACA', departments: ['04', '05', '06', '13', '83', '84'] },
        { code: 'ara', name: 'Auvergne-Rhône-Alpes', departments: ['01', '03', '07', '15', '26', '38', '42', '43', '63', '69', '73', '74'] },
        { code: 'occ', name: 'Occitanie', departments: ['09', '11', '12', '30', '31', '32', '34', '46', '48', '65', '66', '81', '82'] },
      ],
    };
  },

  mounted() {
    this.getDepartments();
    this.initMap();
  },

  methods: {
    async getDepartments(search = '') {
      this.loadingDepartments = true;
      try {
        const response = await this.$api.getDepartments({ search });
        this.availableDepartments = response.data;
      } catch (e) {
        // console.error('Error loading departments:', e);
      } finally {
        this.loadingDepartments = false;
      }
    },

    setPopulationRange(min, max) {
      this.filters.populationMin = min;
      this.filters.populationMax = max;
    },

    isPopulationRangeActive(min, max) {
      return this.filters.populationMin === min && this.filters.populationMax === max;
    },

    selectRegion(region) {
      if (this.isRegionSelected(region)) {
        // Remove region departments
        this.filters.departments = this.filters.departments.filter(
          (dept) => !region.departments.includes(dept.code),
        );
      } else {
        // Add region departments
        const regionDepts = this.availableDepartments.filter(
          (dept) => region.departments.includes(dept.code),
        );
        this.filters.departments = [...this.filters.departments, ...regionDepts];
      }
    },

    isRegionSelected(region) {
      return region.departments.every((code) => this.filters.departments.some((dept) => dept.code === code));
    },

    async applyFilters() {
      this.searching = true;
      try {
        const params = {
          populationMin: this.filters.populationMin,
          populationMax: this.filters.populationMax,
          departments: this.filters.departments.map((d) => d.code).join(','),
        };

        const response = await this.$api.searchMairies(params);
        this.searchResults = response.data;
        this.currentPage = 1;

        if (this.activeTab === 'map') {
          this.updateMap();
        }

        this.$buefy.toast.open({
          message: this.$t('mairies.targeting.searchSuccess', {
            count: this.searchResults.total,
          }),
          type: 'is-success',
        });
      } catch (e) {
        this.$buefy.toast.open({
          message: this.$t('mairies.targeting.searchError'),
          type: 'is-danger',
        });
      } finally {
        this.searching = false;
      }
    },

    clearFilters() {
      this.filters = {
        populationMin: null,
        populationMax: null,
        departments: [],
      };
      this.searchResults = null;
      if (this.map) {
        this.map.eachLayer((layer) => {
          if (layer.options && layer.options.isMarker) {
            this.map.removeLayer(layer);
          }
        });
      }
    },

    async exportResults() {
      if (!this.searchResults) return;

      this.exporting = true;
      try {
        const params = {
          populationMin: this.filters.populationMin,
          populationMax: this.filters.populationMax,
          departments: this.filters.departments.map((d) => d.code).join(','),
          format: 'csv',
        };

        const response = await this.$api.exportMairies(params);
        const blob = new Blob([response.data], { type: 'text/csv' });
        const url = window.URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `mairies-export-${new Date().toISOString().split('T')[0]}.csv`;
        link.click();
        window.URL.revokeObjectURL(url);

        this.$buefy.toast.open({
          message: this.$t('mairies.targeting.exportSuccess'),
          type: 'is-success',
        });
      } catch (e) {
        this.$buefy.toast.open({
          message: this.$t('mairies.targeting.exportError'),
          type: 'is-danger',
        });
      } finally {
        this.exporting = false;
      }
    },

    initMap() {
      // Initialize Leaflet map (placeholder for now)
      // In a real implementation, you would use Leaflet.js
      // console.log('Map initialization placeholder');
    },

    updateMap() {
      // Update map with search results
      // console.log('Map update placeholder', this.searchResults);
    },

    onMarkerClick(mairie) {
      // Basculer vers l'onglet liste et mettre en évidence la mairie
      this.activeTab = 'list';

      // Optionnel : faire défiler vers la mairie dans la liste
      this.$nextTick(() => {
        const element = document.querySelector(`[data-mairie-id="${mairie.id}"]`);
        if (element) {
          element.scrollIntoView({ behavior: 'smooth', block: 'center' });
          element.classList.add('is-highlighted');
          setTimeout(() => {
            element.classList.remove('is-highlighted');
          }, 3000);
        }
      });
    },

    formatNumber(num) {
      return new Intl.NumberFormat('fr-FR').format(num);
    },
  },
};
</script>

<style lang="scss" scoped>
.mairies-targeting {
  .map-container {
    position: relative;
    height: 500px;

    .map {
      width: 100%;
      height: 100%;
      background: #f5f5f5;
      border-radius: 6px;
    }

    .map-placeholder {
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      display: flex;
      align-items: center;
      justify-content: center;
      background: rgba(245, 245, 245, 0.9);
      border-radius: 6px;
    }
  }

  .notification {
    margin-top: 1rem;
  }

  .tabs {
    margin-bottom: 1rem;
  }
}
</style>
