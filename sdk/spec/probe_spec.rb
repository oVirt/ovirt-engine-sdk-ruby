describe SDK::Probing::Probe do

  context '#probe' do
    context 'when api v3' do
      before(:all) do
        start_server
        set_support_only_api_v3
      end

      it 'detects v3 api' do
        connection_params = {
          :url => test_url,
          :token => test_token,
          :ca_file => test_ca_file,
          :debug => test_debug,
          :log => test_log,
        }
        res = described_class.probe(connection_params)
        expect(res).to match_array(["3"])
      end
      after(:all) do
        stop_server
      end
    end

    context 'when supports both v3 and v4 api' do
      before(:all) do
        start_server
        set_support_for_api_v3_and_v4
      end

      it 'detects v3 and v4 api' do
        connection_params = {
          :url => test_url,
          :token => test_token,
          :ca_file => test_ca_file,
          :debug => test_debug,
          :log => test_log,
        }
        res = described_class.probe(connection_params)
        expect(res).to match_array(["3", "4"])
      end
      after(:all) do
        stop_server
      end
    end

    context 'when supports only v4 api' do
      before(:all) do
        start_server
        set_support_only_api_v4
      end

      it 'detects v4 api' do
        connection_params = {
          :url => test_url,
          :token => test_token,
          :ca_file => test_ca_file,
          :debug => test_debug,
          :log => test_log,
        }
        res = described_class.probe(connection_params)
        expect(res).to match_array(["4"])
      end
      after(:all) do
        stop_server
      end
    end
  end
end
