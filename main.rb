# frozen_string_literal: true

require 'net/http'
require 'json'
require 'httparty'

def main
  taxas = []
  puts '.Fetching catalogo'
  catalogo = fetch_catalogo
  puts '..Catalogo fetched'
  catalogo.each do |emissor|
    puts ".Fetching emissor: #{emissor['NomeInstituicao']}"
    taxas.append(fetch_emissor(emissor))
    # puts emissor_response
    puts '..Emissor fetched'
  end
  taxas_erros = taxas.select { |t| t[:erro] }
  taxas = taxas.reject { |t| t[:erro] }
  create_csv_file(taxas)
end

def create_csv_file(taxas)
  options = { col_sep: ';', quote_char: '"', force_quotes: true }
  CSV.open('./arquivos/taxas.csv', 'wb', **options) do |csv|
    csv << %w[cnpj_emissor nome_emissor tipo_gasto data_taxa vl_taxa_conversao data_hora_divulgacao]
    taxas.each do |emissor|
      puts "gravando taxas para o emissor #{emissor['emissorNome']}"
      next unless emissor['historicoTaxas']&.kind_of?(Array)

      emissor['historicoTaxas'].each do |taxa|
        csv.puts [emissor['emissorCnpj'], emissor['emissorNome'], *taxa.values]
      end
    end
  end
end

def fetch_emissor(emissor)
  response = HTTParty.get(emissor['URLDados'], verify: false)
  return { erro: "Response was #{response.code}" } if response.code != 200

  { **JSON.parse(response.body), erro: false }
rescue StandardError => e
  puts 'Houve um erro ao capturar a taxa deste emissor'
  { erro: e }
end

def fetch_catalogo
  response = HTTParty.get(get_catalogo_emissores_uri)
  JSON.parse(response.body)['value']
end

def get_catalogo_emissores_uri(tipo = 'ultimo')
  base_url = 'https://olinda.bcb.gov.br/olinda/servico/DASFN/versao/v1/odata/Recursos'
  recurso = tipo == 'ultimo' ? '/itens/ultimo' : '/itens'

  filtros = '$filter='
  filtros += ERB::Util.url_encode("Api eq 'taxas_cartoes'"\
              " and Recurso eq '#{recurso}'"\
              " and Situacao eq 'Produção'")
  quantidade = '$top=10000'
  formato = '$format=json'

  "#{base_url}?#{quantidade}&#{filtros}&#{formato}"
end

main
